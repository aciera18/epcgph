import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/db_helper.dart';
import '../menu/nav_bar_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _otpController = TextEditingController();
  final _mpinController = TextEditingController();

  String deviceId = "Loading...";
  bool isLoading = false;
  bool isOTPRequired = false;
  bool isMPINRequired = false;
  bool isQuickLogin = false;
  bool isCheckingBiometric = false;
  bool canCheckBiometrics = false;

  String? savedEmpno;
  String? savedMPIN;
  String? savedSeqnum;

  final LocalAuthentication auth = LocalAuthentication();
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initDeviceAndCheckQuickLogin();

    // Initialize wave animation for background and floating effects
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _userController.dispose();
    _passController.dispose();
    _otpController.dispose();
    _mpinController.dispose();
    super.dispose();
  }

  // ---------------- INIT ----------------
  Future<void> _initDeviceAndCheckQuickLogin() async {
    await _getDeviceId();
    await _checkSavedLogin();
    await _checkBiometricSupport();

    if (savedEmpno != null && savedMPIN != null && savedSeqnum != null) {
      _attemptAutoBiometric();
    }
  }

  Future<void> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String id = "Unknown";
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        id = info.id ?? info.fingerprint ?? "Android";
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        id = "${info.computerName}-${info.buildNumber}";
      }
      setState(() => deviceId = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''));
    } catch (_) {
      setState(() => deviceId = "UnknownDevice");
    }
  }

  Future<void> _checkSavedLogin() async {
    try {
      final data = await DBHelper.getLastLogin();
      final prefs = await SharedPreferences.getInstance();
      savedEmpno = data?['empno']?.toString() ?? prefs.getString('empno');
      savedMPIN = data?['mpin']?.toString() ?? prefs.getString('mpin');
      savedSeqnum = data?['seqnum']?.toString() ?? prefs.getString('seqnum');
      if (savedEmpno != null && savedMPIN != null && savedSeqnum != null) {
        setState(() => isQuickLogin = true);
      }
    } catch (_) {}
  }

  Future<void> _checkBiometricSupport() async {
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } catch (_) {
      canCheckBiometrics = false;
    }
  }

  Future<void> _attemptAutoBiometric() async {
    setState(() => isCheckingBiometric = true);
    try {
      if (canCheckBiometrics) {
        final didAuthenticate = await auth.authenticate(
          localizedReason: 'Authenticate to login quickly',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (didAuthenticate) {
          _loginWithSavedCredentials();
          return;
        }
      }
      setState(() => isQuickLogin = true);
    } catch (_) {
      setState(() => isQuickLogin = true);
    } finally {
      if (mounted) setState(() => isCheckingBiometric = false);
    }
  }

  void _loginWithSavedCredentials() {
    if (savedEmpno == null || savedMPIN == null || savedSeqnum == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NavBarHomePage(empno: savedEmpno!, seqnum: savedSeqnum!),
      ),
    );
  }

  Future<void> _login() async {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      _showSnack('Please enter both username and password.');
      return;
    }

    if (deviceId == "Loading..." || deviceId.isEmpty) {
      _showSnack("Fetching device ID... please try again.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://pcgfinance.com.ph/LMS/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user': user,
          'pass': pass,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode != 200) {
        _showSnack('Server error: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['otp_sent'] == true) {
        setState(() => isOTPRequired = true);
        _showSnack('OTP sent to your registered email.');
      } else if (data['success'] == true && data['verified'] == true) {
        await _onLoginSuccess(data);
      } else {
        _showSnack(data['message'] ?? 'Login failed. Please try again.');
      }
    } catch (e) {
      _showSnack('Network error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    final user = _userController.text.trim();
    if (otp.isEmpty) {
      _showSnack('Please enter your OTP.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://pcgfinance.com.ph/LMS/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': user, 'otp': otp, 'device_id': deviceId}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['verified'] == true) {
        await _onLoginSuccess(data);
      } else {
        _showSnack(data['message'] ?? 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      _showSnack('Error verifying OTP: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _onLoginSuccess(dynamic data) async {
    final empno = data['empno']?.toString() ?? '';
    final seqnum = data['seqnum']?.toString() ?? '';
    if (empno.isEmpty || seqnum.isEmpty) {
      _showSnack('Login data incomplete. Please try again.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('empno', empno);
    await prefs.setString('seqnum', seqnum);
    await DBHelper.saveLogin(empno, _userController.text.trim(), _passController.text.trim(), seqnum);
    await DBHelper.updateMPIN(empno, '');
    setState(() {
      isOTPRequired = false;
      isMPINRequired = true;
      isQuickLogin = false;
    });
  }

  Future<void> _saveMPIN() async {
    final mpin = _mpinController.text.trim();
    if (mpin.length != 4) {
      _showSnack('Please enter a valid 4-digit MPIN');
      return;
    }
    final data = await DBHelper.getLastLogin();
    final prefs = await SharedPreferences.getInstance();
    final empno = data?['empno']?.toString() ?? prefs.getString('empno');
    final seqnum = data?['seqnum']?.toString() ?? prefs.getString('seqnum');
    if (empno == null || seqnum == null) {
      _showSnack('No saved login found. Please login again.');
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    await DBHelper.updateMPIN(empno, mpin);
    await prefs.setString('mpin', mpin);
    _showSnack('MPIN saved successfully!');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NavBarHomePage(empno: empno, seqnum: seqnum)));
  }

  Future<void> _loginWithMPIN() async {
    final mpinInput = _mpinController.text.trim();
    if (mpinInput != savedMPIN) {
      _showSnack('Invalid MPIN');
      return;
    }
    _loginWithSavedCredentials();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1️⃣ Wave background
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) => CustomPaint(
              painter: MultiWavePainter(_waveController.value),
              child: Container(),
            ),
          ),

          // 2️⃣ Clouds
          Positioned(
            top: 50,
            left: 30 + 50 * sin(_waveController.value * 2 * pi),
            child: Image.asset('assets/cloud.png', width: 80),
          ),
          Positioned(
            top: 80,
            right: 40 + 40 * cos(_waveController.value * 2 * pi * 1.2),
            child: Image.asset('assets/cloud.png', width: 60),
          ),

          // 3️⃣ Floating logo and login forms
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Transform.translate(
                    offset: Offset(0, 15 * sin(_waveController.value * 2 * pi)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/pcg.png',
                        height: 200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4️⃣ Login Forms
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : isOTPRequired
                        ? _buildOTPInput()
                        : isMPINRequired
                        ? _buildMPINSetup()
                        : isQuickLogin
                        ? _buildQuickLogin()
                        : _buildLoginForm(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --- UI Components ---
  Widget _buildLoginForm() => _card(
    child: Column(
      children: [
        const Text('Welcome to PCG\nPayslip Mobile App',textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Sign in to continue', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        _inputBox(_userController, 'Username', Icons.person),
        const SizedBox(height: 12),
        _inputBox(_passController, 'Password', Icons.lock, isPassword: true),
        const SizedBox(height: 20),
        _button('Login', _login),
      ],
    ),
  );

  Widget _buildOTPInput() => _card(
    child: Column(
      children: [
        const Icon(Icons.email_outlined, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        const Text('Verify OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Enter the 6-digit code sent to your email.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        _inputBox(_otpController, 'OTP Code', Icons.numbers, isNumber: true),
        const SizedBox(height: 20),
        _button('Verify OTP', _verifyOTP),
      ],
    ),
  );

  Widget _buildMPINSetup() => _card(
    child: Column(
      children: [
        const Icon(Icons.shield_outlined, size: 64, color: Colors.orange),
        const Text('Set your 4-digit MPIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _inputBox(_mpinController, 'MPIN', Icons.pin, isNumber: true),
        const SizedBox(height: 20),
        _button('Save MPIN', _saveMPIN),
      ],
    ),
  );

  Widget _buildQuickLogin() => _card(
    child: isCheckingBiometric
        ? Column(
      children: const [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Checking biometric login...', style: TextStyle(color: Colors.grey)),
      ],
    )
        : Column(
      children: [
        const Icon(Icons.lock_outline, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text('Quick Login', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Employee: $savedEmpno', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        _inputBox(_mpinController, 'Enter MPIN', Icons.pin, isPassword: true),
        const SizedBox(height: 20),
        _button('Login with MPIN', _loginWithMPIN),
      ],
    ),
  );

  Widget _card({required Widget child}) => Card(
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );

  Widget _inputBox(TextEditingController c, String label, IconData icon,
      {bool isPassword = false, bool isNumber = false}) =>
      TextField(
        controller: c,
        obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  Widget _button(String label, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.white)),
    ),
  );
}

// ---------------- Wave Painter ----------------
class MultiWavePainter extends CustomPainter {
  final double animationValue;

  MultiWavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final waves = [
      {'amplitude': 20.0, 'speed': 1.0, 'color': Color(0xFF0D47A1)},
      {'amplitude': 15.0, 'speed': 1.5, 'color': Color(0xFF1976D2)},
      {'amplitude': 10.0, 'speed': 0.8, 'color': Color(0xFF42A5F5)},
    ];

    for (var wave in waves) {
      final path = Path();
      path.moveTo(0, size.height);

      final amplitude = wave['amplitude'] as double;
      final speed = wave['speed'] as double;
      final color = wave['color'] as Color;
      final phase = animationValue * 2 * pi * speed;

      for (double x = 0; x <= size.width; x++) {
        final y = sin((x / size.width * 2 * pi) + phase) * amplitude + size.height * 0.5;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      paint.color = color.withOpacity(0.6);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MultiWavePainter oldDelegate) => true;
}
