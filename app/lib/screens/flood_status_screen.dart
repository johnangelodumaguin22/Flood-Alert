import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/flood_ui.dart';
import '../widgets/gauge.dart';
import 'levels_sheet.dart';

class FloodStatusScreen extends StatelessWidget {
  const FloodStatusScreen({super.key, required this.admin});
  final bool admin;

  static const _headerColor = {
    LevelState.normal: AppColors.okText,
    LevelState.warning: AppColors.amberText,
    LevelState.critical: AppColors.red,
    LevelState.offline: AppColors.off,
    LevelState.noData: AppColors.off,
  };

  String _message(LevelState state, DashboardData d) => switch (state) {
    LevelState.normal => 'Water is at a safe level. Keep monitoring for updates.',
    LevelState.warning => 'Water is rising. Get your go-bag ready and prepare to move to higher ground.',
    LevelState.critical =>
      "High water level detected. Move to higher ground now and follow your barangay's evacuation instructions.",
    LevelState.offline =>
      'No reading in ${ago(d.secondsSinceSeen ?? 0).replaceAll(' ago', '')}. '
          "Showing the last reading received. Check the station's power and Wi-Fi.",
    LevelState.noData => 'No readings from the station yet.',
  };

  Future<void> _editLevels(BuildContext context, DashboardData d) async {
    final saved = await showLevelsSheet(context, warnCm: d.warnCm, critCm: d.critCm, maxCm: d.maxCm);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert levels saved. The station will use them within a minute.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveStation(
      builder: (context, d, error) {
        final state = stateOf(d);
        final look = looks[state]!;
        void back() => Navigator.of(context).pop();
        return Scaffold(
          body: Column(
            children: [
              AppHeader(
                color: _headerColor[state]!,
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: back,
                ),
                alerting: state == LevelState.warning || state == LevelState.critical,
              ),
              Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: look.bg,
                    border: Border(bottom: BorderSide(color: look.edge)),
                  ),
                  child: Row(
                    children: [
                      Icon(look.icon, color: look.fg, size: 26),
                      const SizedBox(width: 12),
                      Text(
                        look.label,
                        style: TextStyle(color: look.fg, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (error != null) ...[NotUpdating(error), const SizedBox(height: 12)],
                            if (d == null)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(child: error == null ? const CircularProgressIndicator() : null),
                              )
                            else ...[
                              WaterLevelCard(data: d, state: state),
                              const SizedBox(height: 14),
                              StatusCard(state: state),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: look.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: look.edge),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(look.icon, color: look.fg, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _message(state, d),
                                        style: TextStyle(color: look.fg, fontSize: 13, height: 1.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _TrendCard(data: d, color: state == LevelState.critical ? AppColors.red : AppColors.blue),
                              const SizedBox(height: 14),
                              _DeviceCard(data: d, state: state),
                              const SizedBox(height: 14),
                              _LevelsCard(data: d, onEdit: admin ? () => _editLevels(context, d) : null),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: state == LevelState.critical ? AppColors.red : AppColors.blue,
                              ),
                              onPressed: back,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back, size: 18),
                                  SizedBox(width: 8),
                                  Text('BACK TO DASHBOARD'),
                                ],
                              ),
                            ),
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
      },
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
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardLabel('LAST HOUR'),
          const SizedBox(height: 10),
          if (h.isEmpty)
            const Text('No readings in the last hour.', style: TextStyle(color: AppColors.slate, fontSize: 14))
          else ...[
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
                  border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.minutesAgo == 0 ? 'Now' : '${p.minutesAgo} min ago',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text('${cm(p.levelCm)} cm', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
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
        Text(k, style: const TextStyle(color: AppColors.slate, fontSize: 13)),
        const SizedBox(height: 4),
        DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          child: v,
        ),
      ],
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        Expanded(child: b),
      ],
    );
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardLabel('STATION DEVICE'),
          const SizedBox(height: 12),
          pair(
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
          ),
          const SizedBox(height: 14),
          pair(
            item('On-site alarm', Text(!live ? 'Unknown' : (data.latest!.buzzerOn ? 'Sounding' : 'Silent'))),
            item('Sensor', const Text('HC-SR04')),
          ),
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
    final w = cm(data.warnCm), c = cm(data.critCm);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardLabel('WHAT THE LEVELS MEAN'),
          const SizedBox(height: 8),
          row(AppColors.safe, 'Below $w cm: normal'),
          row(AppColors.warnFill, '$w to below $c cm: warning, prepare to leave'),
          row(AppColors.crit, '$c cm and above: flood alert, evacuate now'),
          if (onEdit != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Edit levels'),
            ),
          ],
        ],
      ),
    );
  }
}
