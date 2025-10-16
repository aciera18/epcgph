import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../pages/cooperative_page.dart';
import '../payslip/payslip_home_PAGE.dart';

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
      path.moveTo(0, size.height / 2);

      for (double x = 0; x <= size.width; x += 2) {
        final y = sin((x / layer.wavelength * 2 * pi) +
            (progress * layer.speed * 2 * pi) +
            layer.phaseOffset) *
            layer.amplitude +
            size.height / 2;
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

class HomePage extends StatefulWidget {
  final String empno;
  final String seqnum;

  const HomePage({
    super.key,
    required this.empno,
    required this.seqnum,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _waveController;
  late List<_WaveLayer> _waveLayers;

  List<Map<String, dynamic>> payslips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeWave();
      fetchRecentPayslips();
    });
  }

  void _initializeWave() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final random = Random();
    _waveLayers = List.generate(3, (i) {
      return _WaveLayer(
        amplitude: 10 + random.nextDouble() * 10,
        wavelength: 150 + random.nextDouble() * 200,
        speed: 0.3 + random.nextDouble(),
        phaseOffset: random.nextDouble() * 2 * pi,
        opacity: 0.3 + random.nextDouble() * 0.3,
        color: [
          Colors.lightBlueAccent,
          Colors.blueAccent,
          Colors.cyanAccent,
        ][i % 3],
      );
    });
  }

  @override
  void dispose() {
    _waveController?.dispose();
    super.dispose();
  }

  Future<void> fetchRecentPayslips() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
          "https://pcgfinance.com.ph/LMS/get_payslips.php?seqnum=${widget.seqnum}");
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final parsedPayslips = data
              .map((e) => DateTime.tryParse(e['paydate'] ?? ''))
              .whereType<DateTime>()
              .toList();
          parsedPayslips.sort((a, b) => b.compareTo(a));
          setState(() {
            payslips = parsedPayslips.take(3).map((date) {
              return {
                'month': _monthName(date.month),
                'year': date.year.toString(),
              };
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF87CEEB),
                  Color(0xFF1E90FF),
                  Color(0xFF001F3F),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Wave only when initialized
          if (_waveController != null)
            AnimatedBuilder(
              animation: _waveController!,
              builder: (context, child) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _WavePainter(
                      _waveController!.value, _waveLayers),
                );
              },
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeaderCard(widget.empno),
                  const SizedBox(height: 20),
                  Text(
                    "Quick Actions",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
                  const SizedBox(height: 25),
                  Text(
                    "Recent Payslips (Last 3 Months)",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentPayslips(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String empno) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C68FF), Color(0xFF6DD5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Serial # $empno",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            "Welcome Back!",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.notifications, 'label': 'Announcements'},
      {
        'icon': Icons.receipt,
        'label': 'Payslips',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayslipHomePage(
                empno: widget.empno,
                seqnum: widget.seqnum ?? '',
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.account_balance_wallet,
        'label': 'Financing Cooperative',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CooperativePage()),
          );
        }
      },
      {'icon': Icons.calendar_today, 'label': 'Calender Events'},

    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final item = actions[index];
        return GestureDetector(
          onTap: item['onTap'] != null
              ? item['onTap'] as void Function()?
              : () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${item['label']} clicked")),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData,
                    size: 36, color: Colors.blueAccent),
                const SizedBox(height: 10),
                Text(
                  item['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPayslips() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (payslips.isEmpty) {
      return Center(
        child: Text(
          "No recent payslips found.",
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: payslips.map((payslip) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.receipt, color: Colors.white),
            ),
            title: Text(
              "${payslip['month']} ${payslip['year']}",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          );
        }).toList(),
      ),
    );
  }
}
