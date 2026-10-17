import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/form_bits.dart';

String _cm(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Lets an admin change the warning and critical levels. Returns true when saved.
Future<bool?> showLevelsSheet(
  BuildContext context, {
  required double warnCm,
  required double critCm,
  required double maxCm,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.silt,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _LevelsSheet(warnCm: warnCm, critCm: critCm, maxCm: maxCm),
  );
}

class _LevelsSheet extends StatefulWidget {
  const _LevelsSheet({required this.warnCm, required this.critCm, required this.maxCm});
  final double warnCm, critCm, maxCm;

  @override
  State<_LevelsSheet> createState() => _LevelsSheetState();
}

class _LevelsSheetState extends State<_LevelsSheet> {
  final _form = GlobalKey<FormState>();
  late final _warn = TextEditingController(text: _cm(widget.warnCm));
  late final _crit = TextEditingController(text: _cm(widget.critCm));
  bool _busy = false;
  String? _error;

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  String? _checkWarn(String? v) {
    final w = _parse(v!);
    if (w == null) return 'Enter a number in cm.';
    if (w < 1) return 'Use at least 1 cm.';
    final c = _parse(_crit.text);
    if (c != null && w >= c) return 'Must be lower than the critical level.';
    return null;
  }

  String? _checkCrit(String? v) {
    final c = _parse(v!);
    if (c == null) return 'Enter a number in cm.';
    if (c > widget.maxCm) return 'Must be at most ${_cm(widget.maxCm)} cm, the top of the gauge.';
    return null;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.saveLevels(warnCm: _parse(_warn.text)!, critCm: _parse(_crit.text)!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _warn.dispose();
    _crit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputs = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit alert levels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'The station uses the new levels for its lights and alarm within a minute.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (_error != null) ErrorBox(_error!),
              LabeledField(
                label: 'Warning starts at (cm)',
                controller: _warn,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: inputs,
                validator: _checkWarn,
              ),
              LabeledField(
                label: 'Critical starts at (cm)',
                controller: _crit,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: inputs,
                validator: _checkCrit,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy ? const ButtonSpinner() : const Text('Save levels'),
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }
}
