import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/layout.dart';
import 'auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await context.read<AuthProvider>().register(
            fullName: _fullName.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
          );
      // The account is signed in; drop the auth screens so the gate shows home.
      navigator.popUntil((route) => route.isFirst);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Inscription impossible. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: 'Créer un compte',
      subtitle: 'Quelques informations suffisent pour commencer.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              LabeledField(
                label: 'Nom complet',
                controller: _fullName,
                autofillHints: const [AutofillHints.name],
                validator: Validators.fullName,
              ),
              const Gap(AppDimens.md),
              LabeledField(
                label: "Nom d'utilisateur",
                controller: _username,
                autofillHints: const [AutofillHints.newUsername],
                validator: Validators.username,
              ),
              const Gap(AppDimens.md),
              LabeledField(
                label: 'Adresse e-mail',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const Gap(AppDimens.md),
              LabeledField(
                label: 'Mot de passe',
                controller: _password,
                obscure: true,
                helper: '8 caractères minimum, avec lettres et chiffres.',
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
              ),
              const Gap(AppDimens.md),
              LabeledField(
                label: 'Confirmer le mot de passe',
                controller: _confirm,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: Validators.confirmPassword(() => _password.text),
              ),
              if (_error != null) ...[
                const Gap(AppDimens.md),
                FormError(_error!),
              ],
              const Gap(AppDimens.lg),
              AppButton(label: 'Créer mon compte', busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
