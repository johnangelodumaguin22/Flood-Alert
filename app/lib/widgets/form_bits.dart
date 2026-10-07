import 'package:flutter/material.dart';

import '../theme.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.optionalNote,
    this.validator,
    this.keyboard,
    this.autofill,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
  });

  final String label;
  final String? hint, optionalNote;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboard;
  final Iterable<String>? autofill;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              children: [
                if (optionalNote != null)
                  TextSpan(
                    text: ' $optionalNote',
                    style: const TextStyle(fontWeight: FontWeight.w400, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboard,
            autofillHints: autofill,
            obscureText: obscure,
            onFieldSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ],
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.autofill,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      validator: widget.validator,
      autofill: widget.autofill,
      onSubmitted: widget.onSubmitted,
      obscure: _hidden,
      suffix: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.critBg, borderRadius: BorderRadius.circular(10)),
      child: Semantics(
        liveRegion: true,
        child: Text(message, style: const TextStyle(color: AppColors.crit, fontSize: 14)),
      ),
    );
  }
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white));
}
