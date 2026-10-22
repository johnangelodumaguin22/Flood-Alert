import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/flood_ui.dart';
import 'admin_sign_in_screen.dart';
import 'flood_status_screen.dart';
import 'history_screen.dart';
import 'levels_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _admin = false;

  @override
  void initState() {
    super.initState();
    Api.instance.isAdmin().then((a) {
      if (mounted) setState(() => _admin = a);
    });
  }

  Future<void> _signIn() async {
    Navigator.of(context).pop(); // close the drawer
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AdminSignInScreen()));
    if (ok == true && mounted) {
      setState(() => _admin = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in as admin.')));
    }
  }

  Future<void> _signOut() async {
    Navigator.of(context).pop(); // close the drawer
    await Api.instance.logout();
    if (!mounted) return;
    setState(() => _admin = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out of admin.')));
  }

  Future<void> _editLevels(DashboardData d) async {
    Navigator.of(context).pop(); // close the drawer
    final saved = await showLevelsSheet(context, warnCm: d.warnCm, critCm: d.critCm, maxCm: d.maxCm);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert levels saved. The station will use them within a minute.')));
    }
  }

  void _openStatus() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FloodStatusScreen(admin: _admin)));

  @override
  Widget build(BuildContext context) {
    return LiveStation(
      builder: (context, d, error) {
        final state = stateOf(d);
        return Scaffold(
          key: _scaffold,
          drawer: _MenuDrawer(
            onEditLevels: _admin && d != null ? () => _editLevels(d) : null,
            onHistory: _admin && d != null
                ? () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(warnCm: d.warnCm, critCm: d.critCm, maxCm: d.maxCm),
                      ),
                    );
                  }
                : null,
            onStatus: () {
              Navigator.of(context).pop();
              _openStatus();
            },
            onAdmin: _admin ? _signOut : _signIn,
            admin: _admin,
          ),
          body: Column(
            children: [
              AppHeader(
                color: AppColors.navy,
                leading: IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => _scaffold.currentState!.openDrawer(),
                ),
                alerting: state == LevelState.warning || state == LevelState.critical,
                onBell: _openStatus,
              ),
              Expanded(
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
                                Icon(Icons.water_drop_outlined, color: AppColors.blue, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Flood Monitoring',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (error != null) ...[NotUpdating(error), const SizedBox(height: 12)],
                            _LocationCard(name: d?.stationName ?? 'Loading station…'),
                            const SizedBox(height: 14),
                            if (d == null)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(child: error == null ? const CircularProgressIndicator() : null),
                              )
                            else ...[
                              WaterLevelCard(data: d, state: state),
                              const SizedBox(height: 14),
                              StatusCard(state: state),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _openStatus,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('VIEW FLOOD STATUS'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                              ),
                            ],
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Location:', style: TextStyle(fontSize: 11, color: AppColors.slate)),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuDrawer extends StatelessWidget {
  const _MenuDrawer({
    required this.onStatus,
    required this.onAdmin,
    required this.admin,
    this.onEditLevels,
    this.onHistory,
  });
  final VoidCallback onStatus, onAdmin;
  final VoidCallback? onEditLevels, onHistory;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 20), child: Brand()),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined, color: AppColors.blue),
              title: const Text('Flood status'),
              onTap: onStatus,
            ),
            if (onHistory != null)
              ListTile(
                leading: const Icon(Icons.history, color: AppColors.blue),
                title: const Text('Flood history'),
                subtitle: const Text('Admin'),
                onTap: onHistory,
              ),
            if (onEditLevels != null)
              ListTile(
                leading: const Icon(Icons.tune, color: AppColors.blue),
                title: const Text('Edit alert levels'),
                subtitle: const Text('Admin'),
                onTap: onEditLevels,
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: Icon(admin ? Icons.logout : Icons.admin_panel_settings_outlined, color: AppColors.slate),
              title: Text(admin ? 'Sign out of admin' : 'Admin sign-in'),
              onTap: onAdmin,
            ),
          ],
        ),
      ),
    );
  }
}
