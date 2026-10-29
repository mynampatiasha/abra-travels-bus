import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import '../../app/providers.dart';
import '../../routing/driver_routes.dart';

class AuthAccessDriverScreen extends ConsumerStatefulWidget {
  const AuthAccessDriverScreen({super.key});

  @override
  ConsumerState<AuthAccessDriverScreen> createState() => _AuthAccessDriverScreenState();
}

class _AuthAccessDriverScreenState extends ConsumerState<AuthAccessDriverScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  /// The operator gives the driver a temporary password; the code by message is the other way in.
  bool _usePassword = true;
  bool _showPassword = false;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _cleanPhone() {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'[\s()-]+'), '');
    if (raw.startsWith('+')) return raw;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return '+91$digits';
  }

  Future<void> _sendOtp() async {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _cleanPhone();
    final client = ref.read(driverApiClientProvider);

    try {
      await client.post(
        'auth/otp/send',
        body: <String, Object?>{
          'phone': phone,
          'purpose': 'SIGN_IN',
        },
        authenticated: false,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to $phone via SMS/WhatsApp'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      final msg = e.failure is ApiFailure
          ? (e.failure as ApiFailure).message
          : 'Unable to send OTP. Please try again.';
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to send OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _cleanPhone();
    final client = ref.read(driverApiClientProvider);
    final tokenSource = ref.read(driverTokenSourceProvider);

    try {
      final res = await client.post(
        'auth/otp/verify',
        body: <String, Object?>{
          'phone': phone,
          'code': otp,
          'device': <String, Object?>{
            'clientType': 'MOBILE',
            'deviceName': 'Driver Mobile App',
          },
        },
        authenticated: false,
      );

      final data = res.data is Map ? res.data as Map : <String, Object?>{};
      final accessToken = data['accessToken'] as String?;
      tokenSource.token = accessToken;

      // Verify user account role with /me
      final meRes = await client.get('me');
      final meData = meRes.data is Map ? meRes.data as Map : <String, Object?>{};
      final userType = meData['userType'] as String? ??
          (data['user'] is Map ? (data['user'] as Map)['userType'] as String? : null);

      if (userType != 'DRIVER') {
        tokenSource.token = null;
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'This app is for registered Abra drivers only.';
        });
        return;
      }

      final driverName = meData['name'] as String? ??
          (data['user'] is Map ? (data['user'] as Map)['name'] as String? : null) ??
          'Driver ($phone)';

      ref.read(currentDriverProvider.notifier).set(driverName);
      ref.read(driverMockDbProvider).currentDriver = driverName;

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in successfully as $driverName'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      context.go(DriverRoutes.home);
    } on AppException catch (e) {
      tokenSource.token = null;
      if (!mounted) return;
      final msg = e.failure is ApiFailure
          ? (e.failure as ApiFailure).message
          : 'Verification failed. Please check the code and try again.';
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    } catch (_) {
      tokenSource.token = null;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification failed. Please check the code and try again.';
      });
    }
  }

  Future<void> _signInWithPassword() async {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final password = _passwordController.text;
    if (digits.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _cleanPhone();
    final client = ref.read(driverApiClientProvider);
    final tokenSource = ref.read(driverTokenSourceProvider);

    try {
      final res = await client.post(
        'auth/login',
        body: <String, Object?>{
          'identifier': phone,
          'password': password,
          'device': <String, Object?>{'clientType': 'MOBILE', 'deviceName': 'Driver Mobile App'},
        },
        authenticated: false,
      );
      final data = res.data is Map ? res.data as Map : <String, Object?>{};
      tokenSource.token = data['accessToken'] as String?;
      if (tokenSource.token == null) {
        throw StateError('No access token in the sign-in answer');
      }

      // The account must be a driver account
      final meRes = await client.get('me');
      final meData = meRes.data is Map ? meRes.data as Map : <String, Object?>{};
      final user = meData['user'] is Map ? meData['user'] as Map : <String, Object?>{};
      if (user['userType'] != 'DRIVER') {
        tokenSource.token = null;
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'This app is for registered Abra drivers only.';
        });
        return;
      }

      // A password the operator gave: the driver chooses their own before going on
      if (user['mustChangePassword'] == true) {
        if (!mounted) return;
        final changed = await _askNewPassword(currentPassword: password);
        if (!changed) {
          tokenSource.token = null;
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'Please choose your own password to continue.';
          });
          return;
        }
      }

      final driverName = (user['name'] as String?) ?? 'Driver ($phone)';
      ref.read(currentDriverProvider.notifier).set(driverName);
      ref.read(driverMockDbProvider).currentDriver = driverName;
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(DriverRoutes.home);
    } on AppException catch (e) {
      tokenSource.token = null;
      if (!mounted) return;
      final failure = e.failure;
      setState(() {
        _isLoading = false;
        _errorMessage = failure is ApiFailure && failure.message.isNotEmpty
            ? failure.message
            : 'Sign-in failed. Please check your number and password.';
      });
    } catch (_) {
      tokenSource.token = null;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign-in failed. Please try again.';
      });
    }
  }

  /// Asks for a new password until it is saved. Returns false when the driver gives up.
  Future<bool> _askNewPassword({required String currentPassword}) async {
    final first = TextEditingController();
    final second = TextEditingController();
    String? problem;
    bool busy = false;
    final client = ref.read(driverApiClientProvider);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Choose your own password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You signed in with a temporary password. Choose a new one that only you know '
                '(at least 10 characters).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: first,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: second,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Type it again'),
              ),
              if (problem != null) ...[
                const SizedBox(height: 8),
                Text(problem!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (first.text.length < 10) {
                        setDialog(() => problem = 'The password must have at least 10 characters.');
                        return;
                      }
                      if (first.text != second.text) {
                        setDialog(() => problem = 'The two passwords are not the same.');
                        return;
                      }
                      setDialog(() {
                        busy = true;
                        problem = null;
                      });
                      try {
                        await client.post(
                          'me/password',
                          body: <String, Object?>{
                            'currentPassword': currentPassword,
                            'newPassword': first.text,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on AppException catch (e) {
                        final failure = e.failure;
                        setDialog(() {
                          busy = false;
                          problem = failure is ApiFailure && failure.message.isNotEmpty
                              ? failure.message
                              : 'Could not save the password. Please try again.';
                        });
                      } catch (_) {
                        setDialog(() {
                          busy = false;
                          problem = 'Could not save the password. Please try again.';
                        });
                      }
                    },
              child: const Text('Save password'),
            ),
          ],
        ),
      ),
    );
    first.dispose();
    second.dispose();
    return saved ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF12304A), Color(0xFF1677C8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.directions_bus_rounded, color: Colors.white, size: 36),
                        SizedBox(width: 12),
                        Text(
                          'Abra Driver',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with your registered mobile number to access your assigned trips.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFDDF3FC),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Phone & OTP Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Driver Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF12304A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _usePassword
                                  ? 'Sign in with your mobile number and the password from your operator.'
                                  : 'Enter your mobile number to receive a one-time verification code.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 18),

                            // Phone Field
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              enabled: !_otpSent && !_isLoading,
                              decoration: InputDecoration(
                                labelText: 'Mobile Number',
                                prefixText: '+91 ',
                                prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF1677C8)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF1677C8), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),

                            if (_usePassword) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                enabled: !_isLoading,
                                onSubmitted: (_) => _isLoading ? null : _signInWithPassword(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1677C8)),
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _showPassword = !_showPassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],

                            if (!_usePassword && _otpSent) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: '6-digit OTP Code',
                                  hintText: 'Enter OTP sent to mobile',
                                  prefixIcon: const Icon(Icons.lock_clock_outlined, color: Color(0xFF1677C8)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF1677C8), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                              ),
                            ],

                            const SizedBox(height: 20),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1677C8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : (_usePassword ? _signInWithPassword : (_otpSent ? _verifyOtp : _sendOtp)),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _usePassword
                                          ? 'Sign in'
                                          : (_otpSent ? 'Verify & Start Shift' : 'Send Verification Code'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                            ),

                            if (!_usePassword && _otpSent) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _otpSent = false;
                                          _otpController.clear();
                                          _errorMessage = null;
                                        });
                                      },
                                child: const Text(
                                  'Change mobile number',
                                  style: TextStyle(color: Color(0xFF1677C8), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() {
                                        _usePassword = !_usePassword;
                                        _otpSent = false;
                                        _errorMessage = null;
                                      }),
                              child: Text(
                                _usePassword ? 'Sign in with a verification code instead' : 'Sign in with my password',
                                style: const TextStyle(color: Color(0xFF1677C8), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
