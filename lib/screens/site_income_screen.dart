import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import 'site_expenses_screen.dart';
import 'site_ledger_screen.dart';
import '../widgets/dev_branding_badge.dart';
import '../app_config.dart';

class SiteIncomeScreen extends StatefulWidget {
  const SiteIncomeScreen({super.key});

  @override
  State<SiteIncomeScreen> createState() => _SiteIncomeScreenState();
}

class _SiteIncomeScreenState extends State<SiteIncomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('SITE INCOME'),
        actions: const [
           DevBrandingBadge(),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: JarvisTheme.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ACTIVE SITES'),
            Tab(text: 'COMPLETED SITES'),
          ],
        ),
      ),
      floatingActionButton: AppConfig.isReadOnly ? null : FloatingActionButton(
        onPressed: () => _showAddIncomeDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildSiteList(data, 'Active'),
              _buildSiteList(data, 'Completed'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSiteList(DataProvider data, String status) {
    // Filter logic: Check 'status' key. If missing, assume 'Active'
    // Use unfilteredSiteIncome so sites persist across date changes
    final sites = data.unfilteredSiteIncome.where((s) {
       final sStatus = s['status'] ?? 'Active';
       return sStatus == status;
    }).toList();

    if (sites.isEmpty) {
      return Center(
        child: Text(
          'No $status sites found', 
          style: const TextStyle(color: Colors.white54)
        )
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sites.length,
      itemBuilder: (context, index) {
        final site = sites[index];
        final isCompleted = status == 'Completed';

        // Real-time Profit Monitoring
        final estimate = data.parseAmount(site['estimate'] ?? site['received']); // fallback for legacy
        final received = data.parseAmount(site['received']);
        // Sum of all expenses related to this site:
        // 1. All categorical expenses (Labour, Other, etc. from site_expenses table)
        // 2. All vehicle entries (Fuel, Rent, Material from vehicles table)
        // 3. All labour costs from the dedicated labour table
        final totalExpenses = data.allSiteExpenses
            .where((e) => e['site'] == site['site'])
            .fold(0.0, (sum, e) => sum + data.parseAmount(e['amount'])) +
            data.allVehicles
            .where((v) => v['site'] == site['site'])
            .fold(0.0, (sum, v) => sum + data.parseAmount(v['total'])) +
            data.allLabour
            .where((l) => l['site'] == site['site'])
            .fold(0.0, (sum, l) => sum + data.parseAmount(l['advance']) + data.parseAmount(l['balance']));
            
        final profitAmountValue = estimate - totalExpenses;
        final profitPercentValue = estimate > 0 ? (profitAmountValue / estimate * 100) : 0.0;
        
        final profitAmountStr = '₹${profitAmountValue.toInt()}';
        final profitPercentStr = '${profitAmountValue >= 0 ? '+' : ''}${profitPercentValue.toStringAsFixed(1)}%';
        final isSiteProfit = profitAmountValue >= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showSiteOptions(context, site, data, isCompleted),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: JarvisTheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site['site'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: JarvisTheme.primary,
                            ),
                          ),
                          Text(
                            '${site['client']} ${site['work_type'] != null && site['work_type'].toString().isNotEmpty ? '(${site['work_type']})' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: JarvisTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSiteProfit 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profitPercentStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSiteProfit ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfo('Estimate', '₹${estimate.toInt()}', color: JarvisTheme.primary),
                      Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                      _buildInfo('Expense', '₹${totalExpenses.toInt()}', color: Colors.orange), // Changed color to Orange for Expense
                      Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                      _buildInfo('Profit', profitAmountStr, color: isSiteProfit ? Colors.green : Colors.red),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SiteLedgerScreen(siteName: site['site']),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JarvisTheme.primary.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: const Text(
                      'VIEW LEDGER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: JarvisTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfo(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: JarvisTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? JarvisTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddIncomeDialog(BuildContext context, {Map<String, dynamic>? site}) {
    final siteNameController = TextEditingController(text: site != null ? site['site'] : '');
    final clientController = TextEditingController(text: site != null ? site['client'] : '');
    final workTypeController = TextEditingController(text: site != null ? site['work_type'] ?? '' : '');
    final estimateController = TextEditingController(text: site != null ? (site['estimate'] ?? site['received'] ?? '').toString().replaceAll('₹', '').replaceAll(',', '') : '');
    final receivedController = TextEditingController(text: site != null ? (site['received'] ?? '').toString().replaceAll('₹', '').replaceAll(',', '') : '');
    final pendingController = TextEditingController(text: site != null ? (site['pending'] ?? '').toString().replaceAll('₹', '').replaceAll(',', '') : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(site != null ? 'Edit Site Income' : 'Add Site Income'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: siteNameController,
                  decoration: const InputDecoration(labelText: 'Site Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(labelText: 'Client Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: workTypeController,
                  decoration: const InputDecoration(labelText: 'Work Type (e.g. Electrical)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: estimateController,
                  decoration: const InputDecoration(labelText: 'Estimate Amount Received (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: receivedController,
                  decoration: const InputDecoration(labelText: 'Amount Received so far (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pendingController,
                  decoration: const InputDecoration(labelText: 'Pending Balance (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                // Date picker removed for Site creation as per request
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (siteNameController.text.isNotEmpty) {
                   final newData = {
                      'site': siteNameController.text,
                      'client': clientController.text,
                      'work_type': workTypeController.text,
                       'estimate': '₹${estimateController.text}',
                       'received': '₹${receivedController.text}',
                       'pending': '₹${pendingController.text}',
                       // Persistence: Keep existing date or set to today for sorting, but it won't affect visibility
                       'date': site != null ? site['date'] : DateFormat('dd MMM yyyy').format(DateTime.now()),
                   };

                  if (site != null) {
                    Provider.of<DataProvider>(context, listen: false).updateIncome(
                      site['id'],
                      newData
                    );
                  } else {
                    Provider.of<DataProvider>(context, listen: false).addIncome(newData);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, String siteName) {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteLedgerScreen(siteName: siteName),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> site) {
    final amountController = TextEditingController();
    DateTime selectedDate = Provider.of<DataProvider>(context, listen: false).selectedDate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Receipt'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                   controller: amountController,
                   decoration: const InputDecoration(labelText: 'Amount Received (₹)'),
                   keyboardType: TextInputType.number,
                   autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(
                       child: Text(
                         'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                         style: const TextStyle(fontWeight: FontWeight.bold),
                       )
                     ),
                     IconButton(
                       icon: const Icon(Icons.calendar_today),
                       onPressed: () async {
                          final picked = await showDatePicker(
                            context: context, 
                            initialDate: selectedDate,
                            firstDate: DateTime(2020), 
                            lastDate: DateTime(2030)
                          );
                          if(picked != null) setState(() => selectedDate = picked);
                       }
                     )
                  ]
                )
              ],
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
               ElevatedButton(
                 onPressed: () {
                    if (amountController.text.isNotEmpty) {
                      double currentRecv = 0.0;
                      if (site['received'] != null) {
                        String s = site['received'].toString().replaceAll('₹', '').replaceAll(',', '');
                        currentRecv = double.tryParse(s) ?? 0.0;
                      }
                      
                      double currentPend = 0.0;
                      if (site['pending'] != null) {
                        String s = site['pending'].toString().replaceAll('₹', '').replaceAll(',', '');
                        currentPend = double.tryParse(s) ?? 0.0;
                      }

                      double add = double.tryParse(amountController.text) ?? 0.0;
                      
                      if (add > 0) {
                        double newRecv = currentRecv + add;
                        double newPend = currentPend - add;
                        
                        Provider.of<DataProvider>(context, listen: false).updateIncome(
                           site['id'],
                           {
                             'received': '₹${newRecv.toStringAsFixed(0)}',
                             'pending': '₹${newPend.toStringAsFixed(0)}',
                             'date': DateFormat('dd MMM yyyy').format(selectedDate),
                           }
                        );
                      }
                    }
                    Navigator.pop(context);
                 },
                 child: const Text('SAVE'), // or ADD
               )
            ]
          );
        }
      )
    );
  }

  void _showSiteOptions(BuildContext context, Map<String, dynamic> site, DataProvider data, bool isCompleted) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: JarvisTheme.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.business, color: JarvisTheme.primary),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site['site'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(site['client'], style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (!AppConfig.isReadOnly) ...[
                if (!isCompleted)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline, color: Colors.green),
                    title: const Text('Add Receipt'),
                    onTap: () {
                      Navigator.pop(context);
                      _showPaymentDialog(context, site);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                  title: const Text('Edit Site Details'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddIncomeDialog(context, site: site);
                  },
                ),
                ListTile(
                  leading: Icon(isCompleted ? Icons.restore : Icons.check_circle_outline, color: Colors.orange),
                  title: Text(isCompleted ? 'Mark as Active' : 'Mark as Completed'),
                  onTap: () {
                    Navigator.pop(context);
                    data.updateIncome(site['id'], {'status': isCompleted ? 'Active' : 'Completed'});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Entry'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmDialog(context, site, data);
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Colors.amber),
                title: const Text('Expenses'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SiteExpensesScreen(initialSite: site['site']),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _showDeleteConfirmDialog(BuildContext context, Map<String, dynamic> site, DataProvider data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete ${site['site']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              data.deleteIncome(site['id']);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
