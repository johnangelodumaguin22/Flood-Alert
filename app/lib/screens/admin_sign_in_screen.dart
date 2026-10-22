import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/form_bits.dart';

/// Barangay admin sign-in, opened from the dashboard menu. Pops true once signed in.
class AdminSignInScreen extends StatefulWidget {
  const AdminSignInScreen({super.key});

  @override
  State<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends State<AdminSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.adminSignIn(_id.text.trim(), _pw.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.page, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 8, bottom: 32), child: Brand()),
                    const Text('Admin sign-in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'For barangay admins only. Residents can view the water level without signing in.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ErrorBox(_error!),
                    LabeledField(
                      label: 'Email or username',
                      controller: _id,
                      hint: 'admin@email.com',
                      autofill: const [AutofillHints.username],
                      validator: (v) => v!.trim().isEmpty ? 'Enter your email or username.' : null,
                    ),
                    PasswordField(
                      label: 'Password',
                      controller: _pw,
                      hint: 'Your password',
                      autofill: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      validator: (v) => v!.isEmpty ? 'Enter your password.' : null,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const ButtonSpinner() : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
