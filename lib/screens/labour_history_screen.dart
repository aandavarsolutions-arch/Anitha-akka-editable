import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../theme.dart';

class LabourHistoryScreen extends StatelessWidget {
  final String labourId;
  final String labourName;

  const LabourHistoryScreen({
    super.key,
    required this.labourId,
    required this.labourName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Labour History',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              labourName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _buildPaymentList(context),
    );
  }

  Widget _buildPaymentList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<DataProvider>(context, listen: false).getLabourPayments(labourId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No payment records found.',
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
                child: const Icon(Icons.payment, color: Colors.green),
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
}
