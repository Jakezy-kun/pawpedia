import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'shell/main_shell.dart';

/// Decides which part of the app the user lands in, and re-decides whenever
/// auth changes.
///
/// This is the only place that navigation depends on auth state. Because
/// `AuthProvider` is driven by `onAuthStateChange`, a session expiring or a
/// sign-out happening anywhere — including from another device — moves the app
/// without any screen having to push or pop.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        // Still restoring a persisted session. Showing the brand rather than
        // Onboarding avoids a flash of the login screen for a signed-in user.
        return const _SplashScreen();

      case AuthStatus.signedIn:
      case AuthStatus.guest:
        return const MainShell();

      case AuthStatus.signedOut:
        return auth.hasSeenOnboarding
            ? const LoginScreen()
            : const OnboardingScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          height: 34,
          width: 34,
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}
