import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

enum LevelState { normal, warning, critical, offline, noData }

LevelState stateOf(DashboardData? d) {
  if (d == null || d.latest == null) return LevelState.noData;
  if (!d.online) return LevelState.offline;
  return switch (d.latest!.status) {
    'critical' => LevelState.critical,
    'warning' => LevelState.warning,
    _ => LevelState.normal,
  };
}

class Look {
  const Look(this.label, this.icon, this.fg, this.bg, this.edge);
  final String label;
  final IconData icon;
  final Color fg, bg, edge;
}

const looks = {
  LevelState.normal: Look('NORMAL', Icons.check_circle_outline, AppColors.okText, AppColors.okBg, AppColors.okEdge),
  LevelState.warning: Look(
    'WARNING',
    Icons.warning_amber_rounded,
    AppColors.amberText,
    AppColors.amberBg,
    AppColors.amberEdge,
  ),
  LevelState.critical: Look(
    'FLOOD ALERT',
    Icons.warning_amber_rounded,
    AppColors.red,
    AppColors.redBg,
    AppColors.redEdge,
  ),
  LevelState.offline: Look('NO SIGNAL', Icons.wifi_off, AppColors.slate, AppColors.offBg, AppColors.line),
  LevelState.noData: Look('WAITING', Icons.hourglass_empty, AppColors.slate, AppColors.offBg, AppColors.line),
};

String cm(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String ago(int s) {
  if (s < 60) return '$s second${s == 1 ? '' : 's'} ago';
  final m = s ~/ 60;
  if (m < 60) return '$m minute${m == 1 ? '' : 's'} ago';
  final h = m ~/ 60;
  if (h < 48) return '$h hour${h == 1 ? '' : 's'} ago';
  return '${h ~/ 24} days ago';
}

/// Subscribes to the live station data for as long as it is on screen.
class LiveStation extends StatefulWidget {
  const LiveStation({super.key, required this.builder});
  final Widget Function(BuildContext context, DashboardData? data, String? error) builder;

  @override
  State<LiveStation> createState() => _LiveStationState();
}

class _LiveStationState extends State<LiveStation> {
  DashboardData? _data;
  String? _error;
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
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _data, _error);
}

/// The coloured bar at the top of each screen.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.color, required this.leading, this.alerting = false, this.onBell});
  final Color color;
  final Widget leading;
  final bool alerting;
  final VoidCallback? onBell;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 4),
              leading,
              const Expanded(
                child: Text(
                  'FLOOD ALERT SYSTEM',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
              ),
              IconButton(
                tooltip: 'Flood status',
                onPressed: onBell,
                icon: Badge(
                  isLabelVisible: alerting,
                  backgroundColor: AppColors.amberEdge,
                  smallSize: 9,
                  child: const Icon(Icons.notifications_none, color: Colors.white),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: AppColors.slate, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
  );
}

class WaterLevelCard extends StatelessWidget {
  const WaterLevelCard({super.key, required this.data, required this.state});
  final DashboardData data;
  final LevelState state;

  @override
  Widget build(BuildContext context) {
    final latest = data.latest;
    final critical = state == LevelState.critical;
    final accent = critical ? AppColors.red : (latest == null || !data.online ? AppColors.off : AppColors.blue);
    return CardBox(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: critical ? AppColors.redBg : AppColors.blueBg, shape: BoxShape.circle),
                child: Icon(
                  critical ? Icons.format_color_reset_outlined : Icons.water_drop_outlined,
                  size: 17,
                  color: accent,
                ),
              ),
              const Spacer(),
              const CardLabel('WATER LEVEL'),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: latest == null ? 'Water level unknown' : 'Water level ${cm(latest.levelCm)} centimetres',
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: latest == null ? '--' : cm(latest.levelCm)),
                  const TextSpan(
                    text: ' cm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _LevelBar(level: latest?.levelCm ?? 0, max: data.maxCm, color: accent),
          if (latest != null) ...[
            const SizedBox(height: 10),
            Text(
              state == LevelState.offline
                  ? 'Last reading ${ago(latest.secondsAgo)}'
                  : 'Updated ${ago(latest.secondsAgo)}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level, required this.max, required this.color});
  final double level, max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: const Color(0xFFEDF1F6)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: (level / max).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, frac, _) => FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: Stack(
              children: [
                for (var i = 0; i <= 4; i++)
                  Align(
                    alignment: Alignment(-1 + i / 2, -1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: i == 0
                          ? CrossAxisAlignment.start
                          : i == 4
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.center,
                      children: [
                        Container(width: 1, height: 5, color: AppColors.slate),
                        const SizedBox(height: 3),
                        Text('${cm(max * i / 4)} cm', style: const TextStyle(fontSize: 10, color: AppColors.slate)),
                      ],
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

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.state});
  final LevelState state;

  @override
  Widget build(BuildContext context) {
    final look = looks[state]!;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardLabel('STATUS'),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: look.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: look.edge),
              ),
              child: Row(
                children: [
                  Icon(look.icon, color: look.fg, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    look.label,
                    style: TextStyle(color: look.fg, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error strip shown when the live data stops updating.
class NotUpdating extends StatelessWidget {
  const NotUpdating(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.offBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Text('Not updating: $message', style: const TextStyle(fontSize: 13, color: AppColors.text)),
    );
  }
}
