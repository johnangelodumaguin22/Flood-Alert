import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/gauge.dart';
import 'levels_sheet.dart';
import 'login_screen.dart';

enum LevelState { normal, warning, critical, offline, noData }

class _Look {
  const _Look(this.label, this.meaning, this.color, this.bg, this.fill);
  final String label, meaning;
  final Color color, bg, fill;
}

const _looks = {
  LevelState.normal: _Look('Normal', 'Water is at a safe level.', AppColors.safe, AppColors.safeBg, AppColors.water),
  LevelState.warning: _Look(
    'Warning',
    'Water is rising. Prepare to move to higher ground.',
    AppColors.warn,
    AppColors.warnBg,
    AppColors.warnFill,
  ),
  LevelState.critical: _Look(
    'Critical',
    'Flood level reached. Evacuate now.',
    AppColors.crit,
    AppColors.critBg,
    AppColors.crit,
  ),
  LevelState.offline: _Look(
    'No signal',
    'Showing the last reading received.',
    AppColors.off,
    AppColors.offBg,
    AppColors.off,
  ),
  LevelState.noData: _Look(
    'Waiting',
    'No readings from the station yet.',
    AppColors.off,
    AppColors.offBg,
    AppColors.off,
  ),
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  String? _error;
  bool _admin = false;
  StreamSubscription<DashboardData>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Api.instance.dashboard().listen(
      (d) => setState(() {
        _data = d;
        _error = null;
      }),
      onError: (Object e) => setState(() => _error = '$e'),
    );
    Api.instance.isAdmin().then((a) {
      if (mounted) setState(() => _admin = a);
    });
  }

  Future<void> _editLevels(DashboardData d) async {
    final saved = await showLevelsSheet(context, warnCm: d.warnCm, critCm: d.critCm, maxCm: d.maxCm);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert levels saved. The station will use them within a minute.')));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _toLogin() {
    _sub?.cancel();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _signOut() async {
    await Api.instance.logout();
    if (mounted) _toLogin();
  }

  LevelState _state(DashboardData d) {
    if (d.latest == null) return LevelState.noData;
    if (!d.online) return LevelState.offline;
    return switch (d.latest!.status) {
      'critical' => LevelState.critical,
      'warning' => LevelState.warning,
      _ => LevelState.normal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final state = d == null ? LevelState.noData : _state(d);
    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            stationName: d?.stationName ?? 'Loading station…',
            alerting: state == LevelState.warning || state == LevelState.critical,
          ),
          if (d != null) _Banner(state: state, data: d),
          if (_error != null)
            _BannerBox(
              bg: AppColors.offBg,
              fg: AppColors.ink,
              edge: AppColors.off,
              title: 'Not updating',
              body: _error!,
            ),
          Expanded(
            child: d == null
                ? Center(child: _error == null ? const CircularProgressIndicator() : const SizedBox())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            children: [
                              _ReadingCard(data: d, state: state),
                              const SizedBox(height: 16),
                              _TrendCard(data: d, color: _looks[state]!.color),
                              const SizedBox(height: 16),
                              _DeviceCard(data: d, state: state),
                              const SizedBox(height: 16),
                              _LevelsCard(data: d, onEdit: _admin ? () => _editLevels(d) : null),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _signOut, child: const Text('Sign out')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _cm(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _ago(int s) {
  if (s < 60) return '$s second${s == 1 ? '' : 's'} ago';
  final m = s ~/ 60;
  if (m < 60) return '$m minute${m == 1 ? '' : 's'} ago';
  final h = m ~/ 60;
  return '$h hour${h == 1 ? '' : 's'} ago';
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.stationName, required this.alerting});
  final String stationName;
  final bool alerting;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.river,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Flood monitoring',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Badge(
                    isLabelVisible: alerting,
                    backgroundColor: AppColors.crit,
                    smallSize: 9,
                    child: const Icon(Icons.notifications_none, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.place_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(stationName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state, required this.data});
  final LevelState state;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final level = data.latest == null ? '' : _cm(data.latest!.levelCm);
    return switch (state) {
      LevelState.warning => _BannerBox(
        bg: AppColors.warnBg,
        fg: AppColors.ink,
        edge: AppColors.warnFill,
        title: 'Warning: water at $level cm',
        body: 'Get your go-bag ready and watch for updates.',
      ),
      LevelState.critical => _BannerBox(
        bg: AppColors.crit,
        fg: Colors.white,
        pulse: true,
        title: 'Flood alert: water at $level cm',
        body: "Move to higher ground now and follow your barangay's evacuation instructions.",
      ),
      LevelState.offline => _BannerBox(
        bg: AppColors.offBg,
        fg: AppColors.ink,
        edge: AppColors.off,
        title: 'Station not reporting',
        body: data.secondsSinceSeen == null
            ? "Check the station's power and Wi-Fi."
            : "No reading in ${_ago(data.secondsSinceSeen!).replaceAll(' ago', '')}. Check the station's power and Wi-Fi.",
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _BannerBox extends StatefulWidget {
  const _BannerBox({
    required this.bg,
    required this.fg,
    required this.title,
    required this.body,
    this.edge,
    this.pulse = false,
  });
  final Color bg, fg;
  final Color? edge;
  final String title, body;
  final bool pulse;

  @override
  State<_BannerBox> createState() => _BannerBoxState();
}

class _BannerBoxState extends State<_BannerBox> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulse && !MediaQuery.of(context).disableAnimations) {
      _anim.repeat(reverse: true);
    } else {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.pulse ? Color.lerp(widget.bg, const Color(0xFFA8241E), _anim.value) : widget.bg,
            border: widget.edge == null ? null : Border(left: BorderSide(color: widget.edge!, width: 6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: child,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: widget.fg, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.title}\n',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: widget.body),
                  ],
                ),
                style: TextStyle(color: widget.fg, fontSize: 15, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.data, required this.state});
  final DashboardData data;
  final LevelState state;

  @override
  Widget build(BuildContext context) {
    final look = _looks[state]!;
    final latest = data.latest;
    return _CardBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Water level',
                  style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: latest == null ? '--' : _cm(latest.levelCm)),
                      const TextSpan(
                        text: ' cm',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: 0),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -2,
                    color: look.color,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: look.bg, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: look.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        look.label,
                        style: TextStyle(color: look.color, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(look.meaning, style: const TextStyle(fontSize: 14, height: 1.45)),
                const SizedBox(height: 12),
                if (latest != null)
                  Text(
                    state == LevelState.offline
                        ? 'Last reading ${_ago(latest.secondsAgo)}'
                        : 'Updated ${_ago(latest.secondsAgo)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StaffGauge(
            level: latest?.levelCm ?? 0,
            max: data.maxCm,
            warn: data.warnCm,
            crit: data.critCm,
            fill: look.fill,
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data, required this.color});
  final DashboardData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final h = data.history;
    return _CardBox(
      title: 'Last hour',
      child: h.isEmpty
          ? const Text('No readings in the last hour.', style: TextStyle(color: AppColors.muted, fontSize: 14))
          : Column(
              children: [
                Semantics(
                  label: 'Water level trend over the last hour',
                  child: SizedBox(
                    height: 70,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: SparklinePainter(
                        points: h.reversed.map((p) => p.levelCm).toList(),
                        max: data.maxCm,
                        warn: data.warnCm,
                        crit: data.critCm,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final (i, p) in h.take(4).indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.minutesAgo == 0 ? 'Now' : '${p.minutesAgo} min ago',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text('${_cm(p.levelCm)} cm', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.data, required this.state});
  final DashboardData data;
  final LevelState state;

  @override
  Widget build(BuildContext context) {
    final live = data.online && data.latest != null;
    Widget led(Color c, bool on) => Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: on ? c : AppColors.line,
        shape: BoxShape.circle,
        boxShadow: on ? [BoxShadow(color: c, blurRadius: 6)] : null,
      ),
    );
    Widget item(String k, Widget v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          child: v,
        ),
      ],
    );
    return _CardBox(
      title: 'Station device',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.4,
        children: [
          item(
            'Connection',
            Row(children: [led(AppColors.safe, data.online), Text(data.online ? 'Online' : 'Offline')]),
          ),
          item(
            'On-site lights',
            Row(
              children: [
                led(AppColors.safe, live && state == LevelState.normal),
                led(AppColors.warnFill, live && state == LevelState.warning),
                led(AppColors.crit, live && state == LevelState.critical),
              ],
            ),
          ),
          item('On-site alarm', Text(!live ? 'Unknown' : (data.latest!.buzzerOn ? 'Sounding' : 'Silent'))),
          item('Sensor', const Text('HC-SR04')),
        ],
      ),
    );
  }
}

class _LevelsCard extends StatelessWidget {
  const _LevelsCard({required this.data, this.onEdit});
  final DashboardData data;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
    final w = _cm(data.warnCm), c = _cm(data.critCm);
    return _CardBox(
      title: 'What the levels mean',
      child: Column(
        children: [
          row(AppColors.safe, 'Below $w cm: normal'),
          row(AppColors.warnFill, '$w to below $c cm: warning, prepare to leave'),
          row(AppColors.crit, '$c cm and above: critical, evacuate now'),
          if (onEdit != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Edit levels'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
