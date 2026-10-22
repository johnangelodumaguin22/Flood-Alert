import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

const stationId = 'station1';
const offlineAfter = Duration(seconds: 60);
const _badLogin = "That email or password doesn't match an account. Check them and try again.";

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

double _num(Object? v, double fallback) => v is num ? v.toDouble() : fallback;

class StationInfo {
  StationInfo.fromMap(Map m)
    : name = (m['name'] ?? 'Station') as String,
      warnCm = _num(m['warn_cm'], 65),
      critCm = _num(m['crit_cm'], 85),
      maxCm = _num(m['max_cm'], 100);
  final String name;
  final double warnCm, critCm, maxCm;
}

class Reading {
  Reading(this.levelCm, this.status, this.buzzerOn, this.secondsAgo);
  final double levelCm;
  final String status;
  final bool buzzerOn;
  final int secondsAgo;
}

class HistoryPoint {
  HistoryPoint(this.minutesAgo, this.levelCm);
  final int minutesAgo;
  final double levelCm;
}

class HistoryRecord {
  HistoryRecord(this.time, this.levelCm, this.status);
  final DateTime time;
  final double levelCm;
  final String? status; // null for records saved before the station sent a status
}

class DashboardData {
  DashboardData(this._info, this.latest, this.history);
  final StationInfo _info;
  final Reading? latest;
  final List<HistoryPoint> history; // newest first

  String get stationName => _info.name;
  double get warnCm => _info.warnCm;
  double get critCm => _info.critCm;
  double get maxCm => _info.maxCm;
  int? get secondsSinceSeen => latest?.secondsAgo;
  bool get online => latest != null && latest!.secondsAgo <= offlineAfter.inSeconds;
}

String _authMessage(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' => _badLogin,
  'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
  'network-request-failed' => "Can't reach the server. Check your internet connection.",
  'user-disabled' => 'This account has been disabled.',
  _ => e.message ?? 'Something went wrong.',
};

Future<T> _guard<T>(Future<T> Function() f) async {
  try {
    return await f().timeout(const Duration(seconds: 15));
  } on TimeoutException {
    throw ApiException("Can't reach the server. Check your internet connection.");
  } on FirebaseException catch (e) {
    throw ApiException(
      e.code == 'permission-denied' ? 'Access denied by the database rules.' : (e.message ?? 'Something went wrong.'),
    );
  }
}

class Api {
  Api._();
  static final instance = Api._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  DatabaseReference _ref(String path) => FirebaseDatabase.instance.ref(path);

  /// Waits for Firebase to restore a saved admin session, if any.
  Future<void> restoreSession() => _auth.authStateChanges().first;

  /// Signs in with an email or username; only accounts listed in admins/ are kept signed in.
  Future<void> adminSignIn(String login, String password) async {
    var email = login.trim().toLowerCase();
    if (!email.contains('@')) {
      final snap = await _guard(() => _ref('usernames/$email').get());
      if (!snap.exists) throw ApiException(_badLogin);
      email = snap.value as String;
    }
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw ApiException(_authMessage(e));
    }
    if (!await isAdmin()) {
      await _auth.signOut();
      throw ApiException("This account isn't a barangay admin. Ask the system administrator for admin access.");
    }
  }

  Future<void> logout() => _auth.signOut();

  /// Admins are listed at `admins/<uid> = true`, set in the Firebase console.
  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _guard(() => _ref('admins/$uid').get());
      return snap.value == true;
    } on ApiException {
      return false;
    }
  }

  /// The station re-reads these every minute, so LEDs and buzzer follow without a reflash.
  Future<void> saveLevels({required double warnCm, required double critCm}) => _guard(
    () => _ref('stations/$stationId/info').update({
      'warn_cm': warnCm,
      'crit_cm': critCm,
      'updated_by': _auth.currentUser!.uid,
      'updated_at': ServerValue.timestamp,
    }),
  );

  /// Every history record from local midnight to midnight of [day], oldest first.
  Future<List<HistoryRecord>> historyForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final snap = await _guard(
      () =>
          _ref('stations/$stationId/history')
              .orderByChild('ts')
              .startAt(start.millisecondsSinceEpoch)
              .endBefore(end.millisecondsSinceEpoch)
              .get(),
    );
    return [
      for (final c in snap.children)
        if (c.child('ts').value is num && c.child('level_cm').value is num)
          HistoryRecord(
            DateTime.fromMillisecondsSinceEpoch((c.child('ts').value as num).toInt()),
            (c.child('level_cm').value as num).toDouble(),
            c.child('status').value as String?,
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Live dashboard: re-emits on every database change and every 5 s so "seconds ago" and offline state stay current.
  Stream<DashboardData> dashboard() {
    final station = _ref('stations/$stationId');
    final subs = <StreamSubscription>[];
    late final StreamController<DashboardData> out;
    Timer? tick;
    var serverOffsetMs = 0;
    StationInfo? info;
    Map? latest;
    var history = <({int ts, double level})>[];

    void emit() {
      if (info == null || out.isClosed) return;
      final now = DateTime.now().millisecondsSinceEpoch + serverOffsetMs;
      Reading? reading;
      if (latest != null && latest!['ts'] is num) {
        reading = Reading(
          _num(latest!['level_cm'], 0),
          (latest!['status'] ?? 'normal') as String,
          latest!['buzzer_on'] == true,
          ((now - (latest!['ts'] as num)) / 1000).floor().clamp(0, 1 << 31),
        );
      }
      final buckets = <int, List<double>>{};
      for (final h in history) {
        final ageMin = (now - h.ts) / 60000;
        if (ageMin < 0 || ageMin >= 60) continue;
        buckets.putIfAbsent(ageMin ~/ 5 * 5, () => []).add(h.level);
      }
      final points =
          buckets.entries
              .map((e) => HistoryPoint(e.key, (e.value.reduce((a, b) => a + b) / e.value.length * 10).round() / 10))
              .toList()
            ..sort((a, b) => a.minutesAgo.compareTo(b.minutesAgo));
      out.add(DashboardData(info!, reading, points));
    }

    void onError(Object e) {
      if (out.isClosed) return;
      out.addError(
        e is FirebaseException && e.code == 'permission-denied'
            ? ApiException('Access denied by the database rules.')
            : ApiException("Can't load station data. Check your internet connection."),
      );
    }

    out = StreamController<DashboardData>(
      onListen: () {
        subs.add(
          _ref('.info/serverTimeOffset').onValue.listen((e) {
            serverOffsetMs = (e.snapshot.value as num?)?.toInt() ?? 0;
            emit();
          }),
        );
        subs.add(
          station.child('info').onValue.listen((e) {
            if (e.snapshot.value is! Map) {
              out.addError(ApiException('Station "$stationId" is not set up in the database yet.'));
              return;
            }
            info = StationInfo.fromMap(e.snapshot.value as Map);
            emit();
          }, onError: onError),
        );
        subs.add(
          station.child('latest').onValue.listen((e) {
            latest = e.snapshot.value as Map?;
            emit();
          }, onError: onError),
        );
        subs.add(
          station.child('history').orderByChild('ts').limitToLast(120).onValue.listen((e) {
            history = [
              for (final c in e.snapshot.children)
                if (c.child('ts').value is num && c.child('level_cm').value is num)
                  (ts: (c.child('ts').value as num).toInt(), level: (c.child('level_cm').value as num).toDouble()),
            ];
            emit();
          }, onError: onError),
        );
        tick = Timer.periodic(const Duration(seconds: 5), (_) => emit());
      },
      onCancel: () async {
        tick?.cancel();
        for (final s in subs) {
          await s.cancel();
        }
        await out.close();
      },
    );
    return out.stream;
  }
}
