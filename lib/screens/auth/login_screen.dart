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
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the AuthGate swaps this screen for the home shell.
      await context.read<AuthProvider>().login(_identifier.text, _password.text);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Connexion impossible. Réessayez.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Connexion',
      subtitle: 'Connectez-vous pour accéder à votre inventaire.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              LabeledField(
                label: "Nom d'utilisateur ou e-mail",
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                validator: (v) => Validators.required(
                  v,
                  label: "L'identifiant",
                ),
              ),
              const Gap(AppDimens.md),
              LabeledField(
                label: 'Mot de passe',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Le mot de passe est obligatoire.'
                    : null,
              ),
              if (_error != null) ...[
                const Gap(AppDimens.md),
                FormError(_error!),
              ],
              const Gap(AppDimens.lg),
              AppButton(
                label: 'Se connecter',
                busy: _busy,
                onPressed: _submit,
              ),
              const Gap(AppDimens.sm),
              AppButton(
                label: 'Créer un compte',
                style: AppButtonStyle.outlined,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
