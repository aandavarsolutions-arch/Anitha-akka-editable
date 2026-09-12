import 'package:flutter/material.dart';
import 'gst_billing_screen.dart';
import 'gst_history_screen.dart';
import 'gst_products_screen.dart';
import 'gst_customers_screen.dart';
import 'gst_settings_screen.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import '../widgets/dev_branding_badge.dart';

class GstDashboardScreen extends StatelessWidget {
  const GstDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Dashboard'),
        actions: [
          const DevBrandingBadge(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: GridView.extent(
          maxCrossAxisExtent: 300,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildMenuCard(context, 'New Invoice', Icons.receipt_long, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GstBillingScreen()))),
            _buildMenuCard(context, 'Saved Bills', Icons.history, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GstHistoryScreen()))),
            _buildMenuCard(context, 'Products', Icons.inventory, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GstProductsScreen()))),
            _buildMenuCard(context, 'Customers', Icons.people, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GstCustomersScreen()))),
            _buildMenuCard(context, 'Settings', Icons.settings, Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GstSettingsScreen()))),
            _buildMenuCard(context, 'Main Menu', Icons.business, Colors.red, () {
               Navigator.pushAndRemoveUntil(
                 context, 
                 MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                 (route) => false,
               );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }


}
