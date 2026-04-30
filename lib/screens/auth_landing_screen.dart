import 'package:flutter/material.dart';

import '../services/auth_gate_service.dart';
import '../widgets/login_or_create_panel.dart';

/// Full-screen first gate: login/create or continue as local-only for this session.
class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Kharcha Manager',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in or create an account',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              LoginOrCreatePanel(
                showContinueWithoutLogin: true,
                onContinueWithoutLogin: () {
                  AuthGateService.enterGuestSession();
                },
                closeModalOnSuccess: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
