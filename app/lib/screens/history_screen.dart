import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/flood_ui.dart';
import '../widgets/gauge.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String _date(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

String _time(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _hour(int h) => '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}';

String _minutes(int m) => m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';

const _rank = {'normal': 0, 'warning': 1, 'critical': 2};
const _statusState = {'normal': LevelState.normal, 'warning': LevelState.warning, 'critical': LevelState.critical};

class _Event {
  _Event(this.start, this.end, this.peak, this.peakAt, this.status);
  DateTime start, end, peakAt;
  double peak;
  String status;
}

/// Admin view of one day's recorded water levels and flood events.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.warnCm, required this.critCm, required this.maxCm});
  final double warnCm, critCm, maxCm;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _day = _today;
  List<HistoryRecord>? _records;
  String? _error;
  int _load = 0;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final load = ++_load;
    setState(() {
      _records = null;
      _error = null;
    });
    try {
      final r = await Api.instance.historyForDay(_day);
      if (mounted && load == _load) setState(() => _records = r);
    } on ApiException catch (e) {
      if (mounted && load == _load) setState(() => _error = e.message);
    }
  }

  void _go(DateTime day) {
    _day = day;
    _fetch();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_today.year - 2),
      lastDate: _today,
      helpText: 'Show records for',
    );
    if (d != null) _go(d);
  }

  String _statusOf(HistoryRecord r) =>
      r.status ??
      (r.levelCm >= widget.critCm
          ? 'critical'
          : r.levelCm >= widget.warnCm
          ? 'warning'
          : 'normal');

  List<_Event> _events(List<HistoryRecord> rs) {
    final out = <_Event>[];
    _Event? cur;
    for (final r in rs) {
      final s = _statusOf(r);
      final gap = cur != null && r.time.difference(cur.end).inMinutes > 5;
      if (s == 'normal' || gap) cur = null;
      if (s == 'normal') continue;
      if (cur == null) {
        cur = _Event(r.time, r.time, r.levelCm, r.time, s);
        out.add(cur);
      } else {
        cur.end = r.time;
        if (r.levelCm > cur.peak) {
          cur.peak = r.levelCm;
          cur.peakAt = r.time;
        }
        if (_rank[s]! > _rank[cur.status]!) cur.status = s;
      }
    }
    return out.reversed.toList(); // newest first
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _day == _today;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            color: AppColors.navy,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history, color: AppColors.blue, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Flood History',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CardBox(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Previous day',
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: () => _go(DateTime(_day.year, _day.month, _day.day - 1)),
                                ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _pick,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Column(
                                        children: [
                                          Text(
                                            isToday
                                                ? 'Today'
                                                : (_day == DateTime(_today.year, _today.month, _today.day - 1)
                                                      ? 'Yesterday'
                                                      : 'Tap to change date'),
                                            style: const TextStyle(fontSize: 11, color: AppColors.slate),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_outlined,
                                                size: 15,
                                                color: AppColors.blue,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  _date(_day),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Next day',
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: isToday ? null : () => _go(DateTime(_day.year, _day.month, _day.day + 1)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ..._body(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_error != null) return [NotUpdating(_error!)];
    final rs = _records;
    if (rs == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (rs.isEmpty) {
      return const [
        CardBox(
          child: Text('No records for this day.', style: TextStyle(color: AppColors.slate, fontSize: 14)),
        ),
      ];
    }

    final high = rs.reduce((a, b) => b.levelCm > a.levelCm ? b : a);
    final low = rs.reduce((a, b) => b.levelCm < a.levelCm ? b : a);
    final avg = rs.map((r) => r.levelCm).reduce((a, b) => a + b) / rs.length;
    final warnMin = rs.where((r) => _statusOf(r) == 'warning').length; // one record per minute
    final critMin = rs.where((r) => _statusOf(r) == 'critical').length;
    final worst = rs.map(_statusOf).reduce((a, b) => _rank[b]! > _rank[a]! ? b : a);
    final events = _events(rs);

    final hours = <int, List<HistoryRecord>>{};
    for (final r in rs) {
      hours.putIfAbsent(r.time.hour, () => []).add(r);
    }

    Widget stat(String k, String v, [String? sub]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: AppColors.slate, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          v,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
        if (sub != null) Text(sub, style: const TextStyle(color: AppColors.slate, fontSize: 11)),
      ],
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        Expanded(child: b),
      ],
    );

    return [
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: CardLabel('DAY SUMMARY')),
                _Pill(status: worst),
              ],
            ),
            const SizedBox(height: 14),
            pair(
              stat('Highest', '${cm(high.levelCm)} cm', _time(high.time)),
              stat('Lowest', '${cm(low.levelCm)} cm', _time(low.time)),
            ),
            const SizedBox(height: 12),
            pair(
              stat('Average', '${cm((avg * 10).round() / 10)} cm'),
              stat('Readings', '${rs.length}', '${_time(rs.first.time)} – ${_time(rs.last.time)}'),
            ),
            const SizedBox(height: 12),
            pair(stat('In warning', _minutes(warnMin)), stat('In flood alert', _minutes(critMin))),
          ],
        ),
      ),
      const SizedBox(height: 14),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardLabel('WATER LEVEL'),
            const SizedBox(height: 12),
            Semantics(
              label: 'Water level chart for ${_date(_day)}',
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(
                  painter: DayChartPainter(
                    start: DateTime(_day.year, _day.month, _day.day, rs.first.time.hour),
                    end: DateTime(_day.year, _day.month, _day.day, rs.last.time.hour + 1),
                    points: [for (final r in rs) (time: r.time, level: r.levelCm)],
                    max: widget.maxCm,
                    warn: widget.warnCm,
                    crit: widget.critCm,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardLabel('FLOOD EVENTS (${events.length})'),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const Text(
                'Water stayed at a normal level all day.',
                style: TextStyle(color: AppColors.slate, fontSize: 14),
              )
            else
              for (final (i, e) in events.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _time(e.start) == _time(e.end) ? _time(e.start) : '${_time(e.start)} – ${_time(e.end)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Peak ${cm(e.peak)} cm at ${_time(e.peakAt)} · ${_minutes(e.end.difference(e.start).inMinutes + 1)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                      _Pill(status: e.status),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardLabel('HOURLY RECORDS'),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('Hour', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Average', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Highest', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                  ),
                  SizedBox(width: 92),
                ],
              ),
            ),
            for (final h in hours.keys.toList().reversed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('${_hour(h)} – ${_hour((h + 1) % 24)}', style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${cm((hours[h]!.map((r) => r.levelCm).reduce((a, b) => a + b) / hours[h]!.length * 10).round() / 10)} cm',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${cm(hours[h]!.map((r) => r.levelCm).reduce((a, b) => a > b ? a : b))} cm',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _Pill(status: hours[h]!.map(_statusOf).reduce((a, b) => _rank[b]! > _rank[a]! ? b : a)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Older records without a saved status are classed using the current alert levels.',
        style: TextStyle(fontSize: 12, color: AppColors.slate),
      ),
    ];
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final look = looks[_statusState[status]]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: look.bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: look.edge),
      ),
      child: Text(
        status == 'critical' ? 'ALERT' : look.label,
        style: TextStyle(color: look.fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}
