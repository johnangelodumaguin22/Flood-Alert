import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/form_bits.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.login(_id.text.trim(), _pw.text, remember: _remember);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 28, bottom: 32), child: Brand()),
                    const Text('Sign in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Use the email or username you registered with.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ErrorBox(_error!),
                    LabeledField(
                      label: 'Email or username',
                      controller: _id,
                      hint: 'juan@email.com',
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _remember,
                              activeColor: AppColors.river,
                              onChanged: (v) => setState(() => _remember = v!),
                            ),
                            const Text('Keep me signed in'),
                          ],
                        ),
                        TextButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ask your station administrator to reset your password.')),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const ButtonSpinner() : const Text('Sign in'),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('No account yet?', style: TextStyle(color: AppColors.muted, fontSize: 15)),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Create an account'),
                        ),
                      ],
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
