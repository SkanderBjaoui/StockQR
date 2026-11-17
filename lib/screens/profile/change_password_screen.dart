import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/layout.dart';
import '../auth/auth_layout.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context
          .read<AuthProvider>()
          .changePassword(_current.text, _next.text);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mot de passe modifié.')),
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Modification impossible.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: 'Mot de passe',
      subtitle: 'Saisissez votre mot de passe actuel, puis le nouveau.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            LabeledField(
              label: 'Mot de passe actuel',
              controller: _current,
              obscure: true,
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Saisissez votre mot de passe actuel.'
                  : null,
            ),
            const Gap(AppDimens.md),
            LabeledField(
              label: 'Nouveau mot de passe',
              controller: _next,
              obscure: true,
              helper: '8 caractères minimum, avec lettres et chiffres.',
              validator: Validators.password,
            ),
            const Gap(AppDimens.md),
            LabeledField(
              label: 'Confirmer le nouveau mot de passe',
              controller: _confirm,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: Validators.confirmPassword(() => _next.text),
            ),
            if (_error != null) ...[
              const Gap(AppDimens.md),
              FormError(_error!),
            ],
            const Gap(AppDimens.lg),
            AppButton(label: 'Enregistrer', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
