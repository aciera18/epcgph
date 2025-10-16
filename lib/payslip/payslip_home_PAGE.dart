import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db/db_helper.dart';
import 'payslip_detail.dart';

// 🌊 --- WAVE LAYER DATA MODEL ---
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

// 🎨 --- CUSTOM WAVE PAINTER ---
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

// 💧 --- RIPPLE BUBBLE LOADER ---
class OceanRippleLoader extends StatefulWidget {
  const OceanRippleLoader({super.key});

  @override
  State<OceanRippleLoader> createState() => _OceanRippleLoaderState();
}

class _OceanRippleLoaderState extends State<OceanRippleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 80,
        height: 40,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) {
                final offset = (i * 0.3);
                final scale = sin((_controller.value * 2 * pi) + offset) * 0.3 + 1;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withOpacity(0.9 - (i * 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// 🧾 --- PAYSLIP PAGE ---
class PayslipHomePage extends StatefulWidget {
  final String empno;
  final String seqnum;
  final String? username;
  final String? password;

  const PayslipHomePage({
    super.key,
    required this.empno,
    required this.seqnum,
    this.username,
    this.password,
  });

  @override
  State<PayslipHomePage> createState() => _PayslipHomePageState();
}

class _PayslipHomePageState extends State<PayslipHomePage>
    with SingleTickerProviderStateMixin {
  bool isLoading = false;
  bool isOffline = false;

  List<String> serverPaydates = [];
  List<String> localPaydates = [];
  List<String> filteredPaydates = [];

  String selectedYear = 'All';
  List<String> availableYears = [];

  AnimationController? _waveController;
  late List<_WaveLayer> _waveLayers;

  @override
  void initState() {
    super.initState();
    _initializePayslips();
    _initializeWave();
  }

  @override
  void dispose() {
    _waveController?.dispose();
    super.dispose();
  }

  // 🌊 Initialize wave layers
  void _initializeWave() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final random = Random();
    _waveLayers = List.generate(3, (i) {
      return _WaveLayer(
        amplitude: 12 + random.nextDouble() * 10,
        wavelength: 160 + random.nextDouble() * 200,
        speed: 0.4 + random.nextDouble(),
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

  // 🔹 Initialize data
  Future<void> _initializePayslips() async {
    await DBHelper.cleanupExpiredLogins();
    await _loadPaydates();
  }

  Future<void> _loadPaydates() async {
    setState(() => isLoading = true);
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        isOffline = false;
        await _loadPaydatesFromServer();
      } else {
        await _loadLocalPayslips();
      }
    } on SocketException {
      await _loadLocalPayslips();
    }
    setState(() => isLoading = false);
  }

  // 🌐 Load from server
  Future<void> _loadPaydatesFromServer() async {
    try {
      final url = Uri.parse(
          'https://pcgfinance.com.ph/LMS/get_payslips.php?seqnum=${widget.seqnum}');
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is List) {
          serverPaydates =
              data.map((item) => item['paydate'].toString()).toList();
        } else {
          serverPaydates = [];
        }
      } else {
        serverPaydates = [];
      }

      localPaydates = await DBHelper.getPaydates(widget.empno);
      _updateAvailableYears();
    } catch (e) {
      debugPrint('Error fetching payslips: $e');
      await _loadLocalPayslips();
    }
  }

  // 🗃 Offline
  Future<void> _loadLocalPayslips() async {
    isOffline = true;
    serverPaydates = await DBHelper.getPaydates(widget.empno);
    localPaydates = List.from(serverPaydates);
    _updateAvailableYears();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline mode: showing local payslips')),
    );
  }

  // 📅 Filter
  void _updateAvailableYears() {
    final years = serverPaydates
        .map((date) => DateTime.tryParse(date)?.year.toString())
        .whereType<String>()
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a));
    availableYears = years;
    selectedYear = availableYears.isNotEmpty ? availableYears.first : 'All';
    _filterByYear();
  }

  void _filterByYear() {
    if (selectedYear == 'All') {
      filteredPaydates = List.from(serverPaydates);
    } else {
      filteredPaydates = serverPaydates
          .where((d) => DateTime.tryParse(d)?.year.toString() == selectedYear)
          .toList();
    }

    filteredPaydates
        .sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
    setState(() {});
  }

  String _formatPaydate(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[parsed.month - 1]} ${parsed.year}';
  }

  // 🖥️ --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isOffline ? 'Payslips (Offline)' : 'Payslips (Online)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isOffline)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Refresh',
              onPressed: _loadPaydatesFromServer,
            ),
        ],
      ),
      body: Stack(
        children: [
          // 🌊 Wave background
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
          if (_waveController != null)
            AnimatedBuilder(
              animation: _waveController!,
              builder: (context, child) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _WavePainter(_waveController!.value, _waveLayers),
                );
              },
            ),

          SafeArea(
            child: Column(
              children: [
                // 🔽 Year filter
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Filter by Year:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value:
                          availableYears.isNotEmpty ? selectedYear : 'All',
                          underline: const SizedBox(),
                          items: (availableYears.isNotEmpty
                              ? availableYears
                              : ['All'])
                              .map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year),
                          ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedYear = value;
                              _filterByYear();
                            });
                          },
                        ),
                      )
                    ],
                  ),
                ),
                // 📄 Payslip list or loader
                Expanded(
                  child: isLoading
                      ? const OceanRippleLoader()
                      : filteredPaydates.isEmpty
                      ? const Center(
                    child: Text(
                      'No payslips found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    itemCount: filteredPaydates.length,
                    itemBuilder: (context, index) {
                      final paydate = filteredPaydates[index];
                      final isDownloaded =
                      localPaydates.contains(paydate);
                      final formatted = _formatPaydate(paydate);

                      return Container(
                        margin:
                        const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.96),
                              Colors.blue.shade50.withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          title: Text(
                            formatted,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            isDownloaded
                                ? "Downloaded"
                                : "Not downloaded",
                            style: TextStyle(
                              color: isDownloaded
                                  ? Colors.green.shade700
                                  : Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDownloaded
                                  ? Colors.blueAccent
                                  : Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              isDownloaded
                                  ? Icons.visibility
                                  : Icons.download,
                              color: Colors.white,
                            ),
                            label: Text(
                              isDownloaded ? 'View' : 'Download',
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                            onPressed: isDownloaded
                                ? () => viewPayslip(paydate)
                                : isOffline
                                ? null
                                : () =>
                                downloadPayslip(paydate),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💾 Download and View
  Future<void> downloadPayslip(String paydate) async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
          'https://pcgfinance.com.ph/LMS/payslip.php?empno=${widget.empno}&paydate=$paydate');
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        String html = response.body;
        await DBHelper.insertPayslip(widget.empno, paydate, html);
        localPaydates = await DBHelper.getPaydates(widget.empno);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Payslip for ${_formatPaydate(paydate)} downloaded!')),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('Download error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> viewPayslip(String paydate) async {
    final html = await DBHelper.getPayslip(widget.empno, paydate);
    if (html == null || html.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payslip found')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PayslipPage(html: html)),
    );
  }
}
