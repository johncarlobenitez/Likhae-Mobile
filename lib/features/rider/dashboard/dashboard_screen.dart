import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  static const Color _primary = Color(0xFF191816);
  static const Color _bg = Color(0xFFF4F1EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Rider Dashboard',
          style: TextStyle(
            color: _primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining_outlined,
                size: 64, color: Color(0xFFB0A89F)),
            SizedBox(height: 16),
            Text(
              'No deliveries assigned',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Active delivery tasks will appear here.',
              style: TextStyle(color: Color(0xFF76716B), fontSize: 14),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: _primary,
        unselectedItemColor: const Color(0xFFB0A89F),
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 0) context.go('/rider/dashboard');
          if (index == 1) context.go('/rider/scanner');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            activeIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scanner',
          ),
        ],
      ),
    );
  }
}
