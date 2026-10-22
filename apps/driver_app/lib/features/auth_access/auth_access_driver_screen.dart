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
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _cleanPhone() {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.length == 10) return '+91';
    return '+91';
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
                            const Text(
                              'Enter your mobile number to receive a one-time verification code.',
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

                            if (_otpSent) ...[
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
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _otpSent ? 'Verify & Start Shift' : 'Send Verification Code',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                            ),

                            if (_otpSent) ...[
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
