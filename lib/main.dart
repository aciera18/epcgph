import 'dart:math';
import 'package:flutter/material.dart';
import 'menu/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ePCGph Payslip',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    // 🌊 Smooth looping wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // 👆 Swipe anywhere to continue
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 0) {
            _goToLogin();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 0) {
            _goToLogin();
          }
        },
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            final floatOffset = 20 * sin(_waveController.value * 2 * pi);

            return CustomPaint(
              painter: MultiWavePainter(_waveController.value),
              child: SizedBox.expand(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 120),

                    // 🪄 Floating logo animation
                    Transform.translate(
                      offset: Offset(0, floatOffset),
                      child: Image.asset(
                        'assets/newlog.png',
                        height: 300,
                      ),
                    ),

                    const Spacer(),

                    // 🧭 Text + Swipe Animation
                    Padding(
                      padding: const EdgeInsets.only(bottom: 200),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Coast Guard\nFinance Service',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'ui-serif',
                                fontSize: 35,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),


                          const SizedBox(height: 8),
                          const Text(
                            '* MOBILE *',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // 👇 Animated Swipe Hint
                          Transform.translate(
                            offset: Offset(20 * sin(_waveController.value * 2 * pi), 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_back_ios_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                Text(
                                  "Swipe to continue",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MultiWavePainter extends CustomPainter {
  final double animationValue;

  MultiWavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final waves = [
      {'amplitude': 20.0, 'speed': 1.0, 'color': const Color(0xFF0D47A1)},
      {'amplitude': 15.0, 'speed': 1.5, 'color': const Color(0xFF1976D2)},
      {'amplitude': 10.0, 'speed': 0.8, 'color': const Color(0xFF42A5F5)},
    ];

    for (var wave in waves) {
      final path = Path();
      path.moveTo(0, size.height);

      final amplitude = wave['amplitude'] as double;
      final speed = wave['speed'] as double;
      final color = wave['color'] as Color;
      final phase = animationValue * 2 * pi * speed;

      for (double x = 0; x <= size.width; x++) {
        final y = sin((x / size.width * 2 * pi) + phase) * amplitude +
            size.height * 0.5;
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
