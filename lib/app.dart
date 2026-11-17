import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/home_shell.dart';
import 'widgets/common_widgets.dart';

class StockQrApp extends StatelessWidget {
  const StockQrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Decides what to show: splash while the session is restored, the login
/// screen when signed out, the home shell when signed in. Because every
/// protected screen lives under the shell, none is reachable unauthenticated.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) return const Scaffold(body: LoadingView());
    final user = auth.user;
    if (user == null) return const LoginScreen();
    // Keyed by user id so switching accounts rebuilds all per-user state.
    return HomeShell(key: ValueKey(user.id), user: user);
  }
}
