import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../routing/driver_routes.dart';

// ===== 1. MODELS =====
class DriverAccount {
  const DriverAccount({
    required this.name,
    required this.operatorId,
    required this.operatorName,
    required this.phone,
    required this.tripsCount,
  });

  final String name;
  final String operatorId;
  final String operatorName;
  final String phone;
  final int tripsCount;
}

// ===== 2. CONTROLLER =====
class AuthAccessDriverController {
  AuthAccessDriverController(this.ref);
  final Ref ref;

  List<DriverAccount> get accounts {
    final db = ref.read(driverMockDbProvider);
    return db.drivers.map((d) {
      return DriverAccount(
        name: d['name'] as String,
        operatorId: d['operatorId'] as String,
        operatorName: d['operatorName'] as String,
        phone: d['phone'] as String,
        tripsCount: d['tripsCount'] as int,
      );
    }).toList();
  }

  void selectDriver(BuildContext context, DriverAccount driver) {
    ref.read(currentDriverProvider.notifier).set(driver.name);
    ref.read(driverMockDbProvider).currentDriver = driver.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signed in as ${driver.name}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    context.go(DriverRoutes.home);
  }
}

final authAccessDriverControllerProvider =
    Provider<AuthAccessDriverController>((ref) => AuthAccessDriverController(ref));

// ===== 3. SCREEN & WIDGETS =====
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

  void _sendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to +91 $phone via SMS/WhatsApp'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    });
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    final phone = _phoneController.text.trim();
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

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        final driverLabel = 'Driver (+91 $phone)';
        ref.read(currentDriverProvider.notifier).set(driverLabel);
        ref.read(driverMockDbProvider).currentDriver = driverLabel;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in successfully as $driverLabel'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        context.go(DriverRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(authAccessDriverControllerProvider);
    final accounts = controller.accounts;

    // Group by operator if available
    final operatorGroups = <String, List<DriverAccount>>{};
    for (final acc in accounts) {
      operatorGroups.putIfAbsent(acc.operatorName, () => []).add(acc);
    }

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
                      'Sign in with your registered mobile number\nto access your assigned trips.',
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
                              'Enter your phone number to receive a one-time login code.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 18),

                            // Phone Field
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              enabled: !_otpSent,
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
                                onPressed: () {
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

                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Or select assigned driver profile:',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF12304A),
                                ),
                              ),
                              const SizedBox(height: 14),
                              for (final entry in operatorGroups.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                for (final driver in entry.value)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => controller.selectDriver(context, driver),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: const Color(0xFFE0F2FE),
                                                child: Text(
                                                  driver.name.isNotEmpty ? driver.name[0] : 'D',
                                                  style: const TextStyle(
                                                    color: Color(0xFF0369A1),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      driver.name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    Text(
                                                      driver.phone,
                                                      style: const TextStyle(
                                                        color: Color(0xFF64748B),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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
