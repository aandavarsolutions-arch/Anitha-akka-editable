import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/dev_branding_badge.dart';
import 'add_vehicle_payment_screen.dart';
import 'vehicle_payments_screen.dart';
import 'vehicle_registry_screen.dart';
import 'drivers_screen.dart';
import 'supplier_payments_screen.dart';
import 'site_expenses_screen.dart';

class VehicleMenuScreen extends StatelessWidget {
  const VehicleMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('VEHICLE MANAGEMENT'),
        actions: const [DevBrandingBadge()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMenuCard(
            context,
            title: 'New Vehicle Entry',
            subtitle: 'Add new vehicle trip / material sales entry',
            icon: Icons.add_circle_outline,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVehiclePaymentScreen(isOwn: true))),
          ),
          _buildMenuCard(
            context,
            title: 'Own Vehicles',
            subtitle: 'Manage company owned vehicles',
            icon: Icons.local_shipping,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiclePaymentsScreen(isOwn: true))),
          ),
          _buildMenuCard(
            context,
            title: 'Maintenance & Fuel',
            subtitle: 'Track fuel and maintenance expenses',
            icon: Icons.local_gas_station,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SiteExpensesScreen(category: 'Vehicle'))),
          ),
          _buildMenuCard(
            context,
            title: 'Manage Vehicles',
            subtitle: 'Add or edit vehicle registry',
            icon: Icons.settings,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRegistryScreen())),
          ),
          _buildMenuCard(
            context,
            title: 'Suppliers',
            subtitle: 'Manage material suppliers and payments',
            icon: Icons.inventory_2,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaymentsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JarvisTheme.secondary.withValues(alpha: 0.05), // Using secondary color (orange) for vehicles
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: JarvisTheme.secondary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: JarvisTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: JarvisTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
