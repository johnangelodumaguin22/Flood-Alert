import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/form_bits.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _user = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _phone = TextEditingController();
  bool _terms = false;
  bool _termsError = false;
  bool _busy = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  String? _server(String field) => _serverErrors[field];

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _serverErrors = {};
      _termsError = !_terms;
    });
    if (!_form.currentState!.validate() || !_terms) return;
    setState(() => _busy = true);
    try {
      final msg = await Api.instance.register({
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'username': _user.text.trim(),
        'password': _pw.text,
        'phone': _phone.text.replaceAll(RegExp(r'\s'), ''),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _serverErrors = e.fields;
      });
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.silt,
        title: const Text('Back to sign in', style: TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Create an account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(
                        "You'll get alerts when the water at your station reaches a warning or critical level.",
                        style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ErrorBox(_error!),
                      LabeledField(
                        label: 'Full name',
                        controller: _name,
                        hint: 'Juan Dela Cruz',
                        autofill: const [AutofillHints.name],
                        validator: (v) => v!.trim().length < 2 ? 'Enter your full name.' : _server('full_name'),
                      ),
                      LabeledField(
                        label: 'Email',
                        controller: _email,
                        hint: 'juan@email.com',
                        keyboard: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email],
                        validator: (v) => !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!.trim())
                            ? 'Enter a valid email, like name@email.com.'
                            : _server('email'),
                      ),
                      LabeledField(
                        label: 'Username',
                        controller: _user,
                        hint: 'juandc',
                        autofill: const [AutofillHints.newUsername],
                        validator: (v) => !RegExp(r'^[A-Za-z0-9_]{4,20}$').hasMatch(v!.trim())
                            ? 'Use 4–20 letters, numbers or underscores.'
                            : _server('username'),
                      ),
                      PasswordField(
                        label: 'Password',
                        controller: _pw,
                        hint: 'At least 8 characters',
                        autofill: const [AutofillHints.newPassword],
                        validator: (v) => v!.length < 8 || !RegExp(r'\d').hasMatch(v)
                            ? 'Use at least 8 characters with a number.'
                            : _server('password'),
                      ),
                      PasswordField(
                        label: 'Confirm password',
                        controller: _pw2,
                        hint: 'Type it again',
                        autofill: const [AutofillHints.newPassword],
                        validator: (v) => v!.isEmpty || v != _pw.text ? "Passwords don't match." : null,
                      ),
                      LabeledField(
                        label: 'Phone number',
                        optionalNote: '(optional, for SMS alerts later)',
                        controller: _phone,
                        hint: '09XX XXX XXXX',
                        keyboard: TextInputType.phone,
                        autofill: const [AutofillHints.telephoneNumber],
                        validator: (v) {
                          final p = v!.replaceAll(RegExp(r'\s'), '');
                          if (p.isNotEmpty && !RegExp(r'^09\d{9}$').hasMatch(p)) {
                            return 'Enter an 11-digit number starting with 09.';
                          }
                          return _server('phone');
                        },
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _terms,
                            activeColor: AppColors.river,
                            onChanged: (v) => setState(() {
                              _terms = v!;
                              if (_terms) _termsError = false;
                            }),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('I agree to the Terms of Service and Privacy Policy'),
                            ),
                          ),
                        ],
                      ),
                      if (_termsError)
                        const Padding(
                          padding: EdgeInsets.only(left: 12, bottom: 8),
                          child: Text(
                            'Accept the terms to create your account.',
                            style: TextStyle(color: AppColors.crit, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy ? const ButtonSpinner() : const Text('Create account'),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?',
                            style: TextStyle(color: AppColors.muted, fontSize: 15),
                          ),
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Sign in')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
