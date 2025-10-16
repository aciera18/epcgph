import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db/db_helper.dart';
import 'package:flutter/services.dart';

/// 🌊 Wave layer model
class _WaveLayer {
  final double amplitude;
  final double wavelength;
  final double speed;
  final double phaseOffset;
  final double opacity;
  final Color color;

  _WaveLayer({
    required this.amplitude,
    required this.wavelength,
    required this.speed,
    required this.phaseOffset,
    required this.opacity,
    required this.color,
  });
}

/// 🎨 Custom painter that draws multiple wave layers
class _WavePainter extends CustomPainter {
  final double progress;
  final List<_WaveLayer> layers;

  _WavePainter(this.progress, this.layers);

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in layers) {
      final paint = Paint()
        ..color = layer.color.withOpacity(layer.opacity)
        ..style = PaintingStyle.fill;

      final path = Path();
      // Start a little above bottom so waves sit nicely behind content
      path.moveTo(0, size.height * 0.6);

      for (double x = 0; x <= size.width; x += 2) {
        final y = sin((x / layer.wavelength * 2 * pi) +
            (progress * layer.speed * 2 * pi) +
            layer.phaseOffset) *
            layer.amplitude +
            size.height * 0.6;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

/// ---------------- ProfilePage ----------------
class ProfilePage extends StatefulWidget {
  final String empno;
  final String? username;
  final String? password;
  final String? seqnum;

  const ProfilePage({
    super.key,
    required this.empno,
    this.username,
    this.password,
    this.seqnum,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  bool isLoading = false;
  bool isOffline = false;
  Map<String, dynamic>? profileData;

  final String apiUrl = "https://pcgfinance.com.ph/LMS/update_profile.php";

  // Wave animation
  late AnimationController _waveController;
  late List<_WaveLayer> _waveLayers;

  @override
  void initState() {
    super.initState();
    _initWave();
    _loadProfile();
  }

  void _initWave() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    final random = Random();
    _waveLayers = List.generate(3, (i) {
      // Choose a pleasant palette for the profile header
      final palette = [
        const Color(0xFF7FDBFF), // light cyan
        const Color(0xFF39A2DB), // blue
        const Color(0xFF0D6EFD), // deep blue
      ];
      return _WaveLayer(
        amplitude: 8 + random.nextDouble() * 12,
        wavelength: 160 + random.nextDouble() * 220,
        speed: 0.2 + random.nextDouble() * 0.6,
        phaseOffset: random.nextDouble() * 2 * pi,
        opacity: 0.25 + random.nextDouble() * 0.25,
        color: palette[i % palette.length],
      );
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  /// 🔹 Main logic to load profile (online preferred, offline fallback)
  Future<void> _loadProfile() async {
    setState(() => isLoading = true);

    try {
      final result = await InternetAddress.lookup('google.com');
      final online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;

      if (online) {
        isOffline = false;
        await _fetchProfileFromServer(); // ✅ Always refresh when online
      } else {
        isOffline = true;
        await _loadProfileFromLocal();
      }
    } catch (_) {
      isOffline = true;
      await _loadProfileFromLocal();
    }

    setState(() => isLoading = false);
  }

  /// 🔹 Fetch from server and cache locally
  Future<void> _fetchProfileFromServer() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://pcgfinance.com.ph/LMS/get_employee.php?seqnum=${widget.seqnum}'),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> dataMap = jsonDecode(response.body);

        if (dataMap['success'] == true && dataMap['employee'] != null) {
          setState(() {
            profileData = Map<String, dynamic>.from(dataMap['employee']);
            isOffline = false;
          });

          // ✅ Save fresh copy to SQLite
          await DBHelper.saveProfile({
            'seqnum': widget.seqnum!,
            'data': profileData,
          });
          return;
        }
      }

      // ❌ If failed, fallback to local
      await _loadProfileFromLocal();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      await _loadProfileFromLocal();
    }
  }

  /// 🔹 Load cached local data (offline mode)
  Future<void> _loadProfileFromLocal() async {
    final localData = await DBHelper.getProfile(widget.seqnum!);
    if (localData != null) {
      setState(() {
        profileData = Map<String, dynamic>.from(localData['data'] as Map);
      });
    }
  }

  /// 🔹 Unified update for email/password
  Future<void> _updateProfileData({
    String? email,
    String? password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'seqnum': widget.seqnum,
          if (email != null) 'email': email,
          if (password != null) 'password': password,
        },
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Profile updated')),
        );

        // ✅ Update UI locally
        if (email != null) {
          setState(() {
            profileData!['email'] = email;
          });
        }

        // also re-save to local DB to keep cache fresh
        if (profileData != null) {
          await DBHelper.saveProfile({
            'seqnum': widget.seqnum!,
            'data': profileData,
          });
        }
      } else {
        throw Exception(data['message'] ?? 'Update failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  /// 🔹 Save MPIN locally only
  Future<void> _saveMPIN(String mpin) async {
    await DBHelper.updateMPIN(widget.empno, mpin);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MPIN updated locally')),
    );
  }

  /// 🔹 Dialog for change actions (disabled when offline)
  void _showChangeDialog(String type) {
    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes disabled in offline mode'),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    String title = '';
    String label = '';
    String hint = '';
    bool obscure = false;

    switch (type) {
      case 'password':
        title = 'Change Password';
        label = 'New Password';
        hint = 'Enter new password';
        obscure = true;
        break;
      case 'email':
        title = 'Change Email';
        label = 'New Email';
        hint = 'Enter new email address';
        break;
      case 'mpin':
        title = 'Change MPIN';
        label = 'New MPIN';
        hint = 'Enter 4-digit MPIN';
        obscure = true;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          maxLength: type == 'mpin' ? 4 : null,
          keyboardType:
          type == 'mpin' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              Navigator.pop(context);
              if (value.isEmpty) return;

              switch (type) {
                case 'password':
                  await _updateProfileData(password: value);
                  break;
                case 'email':
                  await _updateProfileData(email: value);
                  break;
                case 'mpin':
                  await _saveMPIN(value);
                  break;
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// UI card for profile entries
  Widget _buildInfoCard(String label, String? value, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.blueAccent, size: 24),
          if (icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(
                  value ?? '-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format utility
  String _safe(Map<String, dynamic>? m, String key) {
    if (m == null) return '-';
    final v = m[key];
    return v == null ? '-' : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final headerGradient = const LinearGradient(
      colors: [Color(0xFF4C68FF), Color(0xFF6DD5FA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        title: Text(
          isOffline ? 'Profile (Offline)' : 'Account Info',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 8,
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (value) => _showChangeDialog(value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Change Password'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Change Email'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mpin',
                child: Row(
                  children: [
                    Icon(Icons.pin_outlined, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Change MPIN'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileData == null
          ? const Center(child: Text('Profile not found'))
          : Stack(
        children: [
          // Background gradient + waves (only at the top area visually)
          Column(
            children: [
              SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(gradient: headerGradient),
                    ),
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(MediaQuery.of(context).size.width, 240),
                          painter: _WavePainter(
                              _waveController.value, _waveLayers),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // fill the rest with background color to match
              Expanded(
                child: Container(color: Colors.transparent),
              ),
            ],
          ),

          // Foreground content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  // Avatar & name card elevated above waves
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: headerGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, size: 48, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _safe(profileData, 'full_name'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _safe(profileData, 'rank'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Serial # ${_safe(profileData, 'empno')}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        _buildInfoCard('Serial No', _safe(profileData, 'empno'), icon: Icons.badge),
                        _buildInfoCard('Email', _safe(profileData, 'email'), icon: Icons.email_outlined),
                        _buildInfoCard('TIN', _safe(profileData, 'tin'), icon: Icons.credit_card),
                        _buildInfoCard('Philhealth No', _safe(profileData, 'med_id'), icon: Icons.health_and_safety),
                        _buildInfoCard('PAG-IBIG No', _safe(profileData, 'hdmf_id'), icon: Icons.heart_broken_rounded),
                        const SizedBox(height: 10),
                        if (isOffline)
                          const Text(
                            'You are viewing offline data',
                            style: TextStyle(
                              color: Colors.red,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
