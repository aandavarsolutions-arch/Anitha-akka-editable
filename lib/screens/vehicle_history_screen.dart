import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../theme.dart';

class VehicleHistoryScreen extends StatelessWidget {
  final String vehicleId;
  final String vehicleNumber;
  final bool isOwn;

  const VehicleHistoryScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle History',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                vehicleNumber,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'INCOME'),
              Tab(text: 'EXPENSES'),
            ],
            indicatorColor: JarvisTheme.secondary,
          ),
        ),
        body: TabBarView(
          children: [
            _buildIncomeList(context),
            _buildExpenseList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<DataProvider>(context, listen: false).getVehiclePayments(vehicleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No income records found.',
              style: TextStyle(color: JarvisTheme.textSecondary),
            ),
          );
        }

        final history = snapshot.data!.reversed.toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (ctx, i) => const Divider(),
          itemBuilder: (ctx, i) {
            final item = history[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_downward, color: Colors.green),
              ),
              title: Text(
                item['amount'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
              ),
              subtitle: Text(
                item['date'],
                style: const TextStyle(color: JarvisTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            );
          },
        );
      },
    );
  }

  Widget _buildExpenseList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<DataProvider>(context, listen: false).getVehicleExpenses(vehicleNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No expense records found.',
              style: TextStyle(color: JarvisTheme.textSecondary),
            ),
          );
        }

        final history = snapshot.data!.reversed.toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (ctx, i) => const Divider(),
          itemBuilder: (ctx, i) {
            final item = history[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.red),
              ),
              title: Text(
                item['title'] ?? 'Expense',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['date'] ?? '', style: const TextStyle(color: JarvisTheme.textSecondary)),
                  if (item['vehicle_no'] != null)
                     Text('Vehicle: ${item['vehicle_no']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              trailing: Text(
                item['amount'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
              ),
            );
          },
        );
      },
    );
  }
}
