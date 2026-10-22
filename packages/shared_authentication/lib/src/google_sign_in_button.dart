import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_core/shared_core.dart';

enum SocialSignInProvider { google, apple }

/// Firebase proves the Google identity; the app callback exchanges only its ID
/// token for the existing Abra session. Firebase sessions are cleared afterwards.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    required this.exchange,
    this.enabled = true,
    this.obtainIdToken,
    this.provider = SocialSignInProvider.google,
    this.showTerms = true,
    this.termsAccepted = false,
    this.iconOnly = false,
    super.key,
  });
  final Future<void> Function(String idToken, String? linkPassword) exchange;
  final bool enabled;
  final SocialSignInProvider provider;
  final bool showTerms;
  final bool termsAccepted;
  final bool iconOnly;

  /// Injectable provider for platform integrations and deterministic popup tests.
  final Future<String?> Function()? obtainIdToken;
  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;
  bool _terms = false;
  String? _error;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    FirebaseAuth? auth;
    GoogleSignIn? native;
    try {
      Future<String?> firebaseToken() async {
        const apiKey = String.fromEnvironment('ABRA_FIREBASE_API_KEY');
        const project = String.fromEnvironment('ABRA_FIREBASE_PROJECT_ID');
        if (apiKey.isEmpty || project.isEmpty) {
          throw StateError(
            'Google sign-in is not configured. Contact support.',
          );
        }
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: apiKey,
              projectId: project,
              appId: String.fromEnvironment('ABRA_FIREBASE_APP_ID'),
              messagingSenderId: String.fromEnvironment(
                'ABRA_FIREBASE_MESSAGING_SENDER_ID',
              ),
              authDomain: String.fromEnvironment('ABRA_FIREBASE_AUTH_DOMAIN'),
              storageBucket: String.fromEnvironment(
                'ABRA_FIREBASE_STORAGE_BUCKET',
              ),
            ),
          );
        }
        final firebaseAuth = FirebaseAuth.instance;
        auth = firebaseAuth;
        UserCredential credential;
        if (widget.provider == SocialSignInProvider.apple) {
          final provider = AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
          credential = kIsWeb
              ? await firebaseAuth.signInWithPopup(provider)
              : await firebaseAuth.signInWithProvider(provider);
        } else if (kIsWeb) {
          final provider = GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'});
          credential = await firebaseAuth.signInWithPopup(provider);
        } else {
          final google = GoogleSignIn(
            serverClientId: const String.fromEnvironment(
              'ABRA_GOOGLE_SERVER_CLIENT_ID',
            ),
          );
          native = google;
          final account = await google.signIn();
          if (account == null) return null;
          final tokens = await account.authentication;
          credential = await firebaseAuth.signInWithCredential(
            GoogleAuthProvider.credential(
              idToken: tokens.idToken,
              accessToken: tokens.accessToken,
            ),
          );
        }
        return credential.user?.getIdToken(true);
      }

      final token = await (widget.obtainIdToken ?? firebaseToken)();
      if (token == null) {
        throw StateError('Google sign-in was cancelled.');
      }
      try {
        await widget.exchange(token, null);
      } on AppException catch (e) {
        if (e.failure is! ApiFailure ||
            (e.failure as ApiFailure).details['googleLinkRequired'] != true) {
          rethrow;
        }
        if (!mounted) return;
        final password = await _linkPassword();
        if (password == null) rethrow;
        await widget.exchange(token, password);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'popup-closed-by-user' ||
            'cancelled-popup-request' => 'Google sign-in was cancelled.',
            'popup-blocked' => 'Allow pop-ups for this site and try again.',
            'network-request-failed' => 'Check your connection and try again.',
            'user-disabled' => 'This Google account is disabled.',
            _ => 'Google sign-in failed. Please try again.',
          };
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e is StateError
              ? e.message
              : e is AppException && e.failure is ApiFailure
              ? (e.failure as ApiFailure).message
              : 'Sign-in failed. Please try again.';
        });
      }
    } finally {
      try {
        await auth?.signOut();
        await native?.signOut();
      } on Object {
        /* Abra owns the session. */
      }
      if (mounted) {
        setState(() => _busy = false);
        if (widget.iconOnly && _error != null) {
          final message = widget.provider == SocialSignInProvider.apple
              ? _error!.replaceAll('Google', 'Apple')
              : _error!;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unable to sign in'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (mounted) setState(() => _error = null);
        }
      }
    }
  }

  Future<String?> _linkPassword() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link your existing account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If you already have an Abra account with this email, confirm its current password. Accounts are never merged without this check.',
            ),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showTerms)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _terms,
          onChanged: _busy
              ? null
              : (value) => setState(() => _terms = value ?? false),
          title: const Text('I agree to the terms and privacy policy'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      if (widget.iconOnly)
        Tooltip(
          message: widget.provider == SocialSignInProvider.apple
              ? 'Continue with Apple'
              : 'Continue with Google',
          child: SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed:
                  widget.enabled && (_terms || widget.termsAccepted) && !_busy
                  ? _signIn
                  : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : widget.provider == SocialSignInProvider.apple
                  ? const Icon(
                      Icons.apple,
                      size: 24,
                      color: Colors.black,
                      semanticLabel: 'Continue with Apple',
                    )
                  : Semantics(
                      label: 'Continue with Google',
                      child: const CustomPaint(
                        size: Size(22, 22),
                        painter: _GoogleIconPainter(),
                      ),
                    ),
            ),
          ),
        )
      else
        OutlinedButton.icon(
          onPressed:
              widget.enabled && (_terms || widget.termsAccepted) && !_busy
              ? _signIn
              : null,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : widget.provider == SocialSignInProvider.apple
              ? const Icon(Icons.apple)
              : const Text(
                  'G',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
          label: Text(
            widget.provider == SocialSignInProvider.apple
                ? 'Continue with Apple'
                : 'Continue with Google',
          ),
        ),
      if (_error != null && !widget.iconOnly)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            widget.provider == SocialSignInProvider.apple
                ? _error!.replaceAll('Google', 'Apple')
                : _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}

class _GoogleIconPainter extends CustomPainter {
  const _GoogleIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    const ring = Rect.fromLTWH(3, 3, 18, 18);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(ring, 0, 0.85, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(ring, 0.85, 1.8, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(ring, 2.65, 0.95, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(ring, 3.6, 1.95, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawLine(const Offset(12, 12), const Offset(21, 12), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleIconPainter oldDelegate) => false;
}
