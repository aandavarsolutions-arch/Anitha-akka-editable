import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/summary_tile.dart';
import '../widgets/status_chip.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<Map<String, String?>> _getBusinessInfo(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final name = await provider.getSetting('business_name');
    final logoPath = await provider.getLogoPath();
    return {'name': name, 'logo': logoPath};
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, child) {
        return Scaffold(
          backgroundColor: JarvisTheme.background,
          appBar: AppBar(
            title: const Text('OFFICE DASHBOARD'),
            actions: const [
              DevBrandingBadge(),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. Date Navigator
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: JarvisTheme.primary),
                        onPressed: data.previousDay,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => data.selectDateRange(context),
                        child: Text(
                          data.formattedSelectedDate.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: JarvisTheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: JarvisTheme.primary),
                        onPressed: data.nextDay,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 20, color: JarvisTheme.primary),
                        onPressed: () => data.selectDateRange(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 1. Summary Tiles Row
                  Row(
                    children: [
                      Expanded(
                        child: SummaryTile(
                          title: 'EXPENSE',
                          value: data.totalExpense,
                          icon: Icons.arrow_downward,
                          color: JarvisTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SummaryTile(
                          title: 'INCOME',
                          value: data.totalIncome,
                          icon: Icons.arrow_upward,
                          color: JarvisTheme.statusPaid,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SummaryTile(
                          title: 'PENDING',
                          value: data.totalPending,
                          icon: Icons.warning_amber_rounded,
                          color: JarvisTheme.statusPending,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  
                  // 3. Recent Transactions Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RECENT TRANSACTIONS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: JarvisTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 4. Transaction List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.recentTransactions.length,
                    itemBuilder: (context, index) {
                      final txn = data.recentTransactions[index];
                      return _buildTransactionCard(txn);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: JarvisTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: txn['isExpense'] 
                    ? Colors.red.withValues(alpha: 0.05) 
                    : Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                txn['isExpense'] ? Icons.arrow_downward : Icons.arrow_upward,
                size: 20,
                color: txn['isExpense'] ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          txn['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: JarvisTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        txn['amount'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: JarvisTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          txn['subtitle'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: JarvisTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date
                      Text(
                        txn['date'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: JarvisTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: StatusChip(
                      label: txn['status'] == StatusType.paid 
                          ? 'PAID' 
                          : txn['status'] == StatusType.partial ? 'PARTIAL' : 'PENDING',
                      type: txn['status'],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
