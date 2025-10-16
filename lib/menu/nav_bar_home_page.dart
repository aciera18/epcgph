import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../payslip/payslip_home_page.dart';
import '../account/profile_page.dart';
import '../account/home_page.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

class NavBarHomePage extends StatefulWidget {
  final String empno;
  final String seqnum;

  const NavBarHomePage({
    super.key,
    required this.empno,
    required this.seqnum,
  });

  @override
  State<NavBarHomePage> createState() => _NavBarHomePageState();
}

class _NavBarHomePageState extends State<NavBarHomePage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      HomePage(empno: widget.empno, seqnum: widget.seqnum),
      PayslipHomePage(empno: widget.empno, seqnum: widget.seqnum),
      ProfilePageWithLogout(
        empno: widget.empno,
        seqnum: widget.seqnum,
        onLogout: _handleLogout,
      ),
    ];
  }

  // ---------------- LOGOUT ----------------
  Future<void> _handleLogout() async {
    if (Platform.isAndroid) {
      SystemNavigator.pop(); // close app
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌊 Wave Background - full screen
          Positioned.fill(
            child: WaveWidget(
              config: CustomConfig(
                gradients: [
                  [Colors.blue.shade300, Colors.blue.shade200],
                  [Colors.lightBlueAccent, Colors.blue.shade100],
                ],
                durations: [35000, 19440],
                heightPercentages: [0.20, 0.23],
                blur: const MaskFilter.blur(BlurStyle.solid, 10),
                gradientBegin: Alignment.bottomLeft,
                gradientEnd: Alignment.topRight,
              ),
              waveAmplitude: 2,
              size: const Size(double.infinity, double.infinity),
            ),
          ),

          // 🧭 Active Page
          SafeArea(child: _pages[_currentIndex]),
        ],
      ),

      // 🧭 Bottom Navigation Bar
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        indicatorColor: Colors.blue.shade100,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Payslips',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

// ---------------- PROFILE PAGE WRAPPER ----------------
class ProfilePageWithLogout extends StatelessWidget {
  final String empno;
  final String seqnum;
  final VoidCallback onLogout;

  const ProfilePageWithLogout({
    super.key,
    required this.empno,
    required this.seqnum,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: onLogout,
          ),
        ],
      ),
      body: ProfilePage(
        empno: empno,
        seqnum: seqnum,
      ),
    );
  }
}
