import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../config/app_config.dart';
import '../services/auth_gate_service.dart';
import '../services/account_subscription_service.dart';
import '../services/entitlement_service.dart';
import '../services/firebase_auth_platform_recovery.dart';
import '../services/profile_service.dart';

/// Shared email/password login-or-create flow (Firebase).
class LoginOrCreatePanel extends StatefulWidget {
  const LoginOrCreatePanel({
    super.key,
    this.embedInSheet = false,
    this.onRequestClose,
    this.showContinueWithoutLogin = false,
    this.onContinueWithoutLogin,
    this.closeModalOnSuccess = false,
  });

  final bool embedInSheet;
  final VoidCallback? onRequestClose;

  /// Second CTA: skip Firebase and use local-only session for this run.
  final bool showContinueWithoutLogin;
  final VoidCallback? onContinueWithoutLogin;

  /// When true, [Navigator.pop(context, true)] after successful auth (bottom sheet).
  final bool closeModalOnSuccess;

  @override
  State<LoginOrCreatePanel> createState() => _LoginOrCreatePanelState();
}

class _LoginOrCreatePanelState extends State<LoginOrCreatePanel> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterNewUserRegistered() async {
    if (!AppConfig.firebaseCloudEnabled) return;
    AuthGateService.clearGuestSession();
    await AccountSubscriptionService.ensureFreeAccountFieldsInFirestore();
    await AccountSubscriptionService.syncEntitlementFromFirestore();
    await AccountSubscriptionService.syncEntitlementFromPlayIfFree();
    await EntitlementService.setProSignInRequired(false);
    await ProfileService().ensureDefaultProfileExists();
    await ProfileService().syncActiveProfileForCurrentUser();
    await ProfileService().ensureActiveProfileMembership();
    await ProfileService().refreshCachedActiveProfileId();
  }

  Future<void> _afterExistingUserSignedIn() async {
    if (!AppConfig.firebaseCloudEnabled) return;
    AuthGateService.clearGuestSession();
    await AccountSubscriptionService.syncEntitlementFromFirestore();
    await AccountSubscriptionService.syncEntitlementFromPlayIfFree();
    await EntitlementService.setProSignInRequired(false);
    await ProfileService().ensureDefaultProfileExists();
    await ProfileService().syncActiveProfileForCurrentUser();
    await ProfileService().ensureActiveProfileMembership();
    await ProfileService().refreshCachedActiveProfileId();
  }

  /// Returns true if the current Firebase user was just created (new registration)
  /// vs an existing user signing in. Used in the platform bug recovery path where
  /// the exception interrupts the flow before we know which case we're in.
  /// Compares creationTime vs lastSignInTime — if within 10 seconds, it's new.
  bool _isNewlyRegisteredUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final created = user.metadata.creationTime;
    final lastSignIn = user.metadata.lastSignInTime;
    if (created == null || lastSignIn == null) return false;
    return lastSignIn.difference(created).abs().inSeconds < 10;
  }

  /// Pop on the next frame so auth listeners can settle first.
  /// Clears _busy before scheduling the pop so the spinner stops
  /// immediately even if the frame is delayed.
  void _popModalSuccess() {
    if (!mounted || !widget.closeModalOnSuccess) return;
    // Clear busy immediately so the spinner stops showing.
    if (mounted) setState(() => _busy = false);
    final nav = Navigator.of(context);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Guard: only pop if the sheet is still on top (wasn't already popped
      // by an auth listener racing with this callback).
      if (nav.canPop()) nav.pop(true);
    });
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _error = 'Use a valid email and password (min 6 characters).';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AuthGateService.clearGuestSession();
      if (widget.closeModalOnSuccess) {
        _popModalSuccess();
        unawaited(_afterNewUserRegistered());
      } else {
        if (mounted) setState(() => _busy = false);
        unawaited(_afterNewUserRegistered());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          AuthGateService.clearGuestSession();
          if (widget.closeModalOnSuccess) {
            _popModalSuccess();
            unawaited(_afterExistingUserSignedIn());
          } else {
            if (mounted) setState(() => _busy = false);
            unawaited(_afterExistingUserSignedIn());
          }
          return;
        } on FirebaseAuthException catch (e2) {
          setState(() {
            _busy = false;
            _error = e2.message ?? e2.code;
          });
          return;
        }
      }
      setState(() {
        _busy = false;
        _error = e.message ?? e.code;
      });
    } catch (e, st) {
      assert(() {
        debugPrint('LoginOrCreatePanel error: $e\n$st');
        return true;
      }());
      if (isAuthPlatformDeserializeBug(e) &&
          await waitForAuthUserAfterPlatformBug()) {
        AuthGateService.clearGuestSession();
        // The platform deserialization bug interrupts the flow before we know
        // if this was a new registration or existing sign-in. Check Firebase
        // user metadata to determine which post-auth path to take:
        // - New user (creationTime ≈ lastSignInTime): write free defaults first
        // - Existing user: sync from Firebase + Play without overwriting Pro
        final afterAuth = _isNewlyRegisteredUser()
            ? _afterNewUserRegistered
            : _afterExistingUserSignedIn;
        if (widget.closeModalOnSuccess) {
          _popModalSuccess();
          unawaited(afterAuth());
        } else {
          if (mounted) setState(() => _busy = false);
          unawaited(afterAuth());
        }
        return;
      }
      setState(() {
        _busy = false;
        _error = isAuthPlatformDeserializeBug(e)
            ? 'Connection glitch — try again.'
            : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.embedInSheet
              ? 'Use your email'
              : 'Sign in with an existing account or create a new one. New accounts start as Free.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
        if (widget.showContinueWithoutLogin) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : widget.onContinueWithoutLogin,
            child: const Text('Continue without signing in'),
          ),
        ],
      ],
    );

    if (!widget.embedInSheet) {
      return form;
    }

    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Material(
        color: cs.surface,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sign In / Sign Up',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onRequestClose,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: form,
              ),
            ],
          ),
        ),
      ),
    );
  }
}