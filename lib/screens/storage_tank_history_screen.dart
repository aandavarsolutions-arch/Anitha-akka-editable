import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import 'site_expenses_screen.dart';

class StorageTankHistoryScreen extends StatefulWidget {
  const StorageTankHistoryScreen({super.key});

  @override
  State<StorageTankHistoryScreen> createState() => _StorageTankHistoryScreenState();
}

class _StorageTankHistoryScreenState extends State<StorageTankHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchFuelTankData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isDateInRange(String? dateStr) {
    if (_selectedDateRange == null) return true;
    if (dateStr == null || dateStr.isEmpty) return true;
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
             date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, child) {
        final double availableLiters = data.mainTankLiters;
        final double avgPrice = data.getAverageFuelPricePerLiter();

        // 1. Inflow: Tank Purchases from site_expenses
        final purchases = data.allSiteExpenses.where((e) {
          final vNo = (e['vehicle_no'] ?? '').toString();
          final title = (e['title'] ?? '').toString();
          final isTank = vNo.contains('Storage Tank') || vNo.contains('Tank') || title.contains('Storage Tank');
          return isTank && _isDateInRange(e['date']);
        }).toList();

        double totalPurchasedLiters = 0;
        double totalPurchasedAmount = 0;
        for (var p in purchases) {
          double q = double.tryParse(p['quantity']?.toString() ?? '0') ?? 0;
          if (q <= 0) q = double.tryParse(p['liters']?.toString() ?? '0') ?? 0;
          totalPurchasedLiters += q;
          totalPurchasedAmount += data.parseAmount(p['amount']);
        }

        // 2. Outflow: Fuel Issues to vehicles
        final issues = data.fuelIssues.where((i) => _isDateInRange(i['date']?.toString())).toList();
        double totalIssuedLiters = 0;
        for (var i in issues) {
          totalIssuedLiters += (i['liters'] as num?)?.toDouble() ?? 0.0;
        }

        return Scaffold(
          backgroundColor: JarvisTheme.background,
          appBar: AppBar(
            title: const Text('STORAGE TANK HISTORY'),
            actions: [
              if (_selectedDateRange != null)
                IconButton(
                  icon: const Icon(Icons.highlight_off),
                  tooltip: 'Clear Date Filter',
                  onPressed: () => setState(() => _selectedDateRange = null),
                ),
              IconButton(
                icon: Icon(Icons.date_range, color: _selectedDateRange != null ? JarvisTheme.secondary : null),
                tooltip: 'Filter by Date',
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() => _selectedDateRange = picked);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  data.fetchFuelTankData();
                },
              ),
              const DevBrandingBadge(),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: JarvisTheme.secondary,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'DISPENSED TO VEHICLES'),
                Tab(text: 'TANK PURCHASES'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Tank Summary Metrics Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AVAILABLE STOCK', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${availableLiters.toStringAsFixed(1)} L',
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('AVG RATE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '₹${avgPrice.toStringAsFixed(2)}/L',
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem('Total Purchased', '${totalPurchasedLiters.toStringAsFixed(1)} L', '₹${totalPurchasedAmount.toInt()}', Colors.greenAccent),
                        Container(height: 24, width: 1, color: Colors.white24),
                        _buildSummaryItem('Total Dispensed', '${totalIssuedLiters.toStringAsFixed(1)} L', '₹${(totalIssuedLiters * avgPrice).toInt()}', Colors.orangeAccent),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFuelIssuesList(issues, data),
                    _buildPurchasesList(purchases, data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, String val1, String val2, Color valColor) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(val1, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 6),
            Text('($val2)', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        )
      ],
    );
  }

  Widget _buildFuelIssuesList(List<Map<String, dynamic>> issues, DataProvider data) {
    if (issues.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_gas_station, size: 54, color: Colors.grey),
            SizedBox(height: 12),
            Text('No fuel dispenses recorded', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final item = issues[index];
        final double liters = (item['liters'] as num?)?.toDouble() ?? 0.0;
        final String vNo = item['vehicle_number'] ?? 'Vehicle';
        final String vType = item['vehicle_type'] ?? '';
        final String driver = item['driver_name'] ?? '';
        final String hours = item['odometer_hours'] ?? '';
        final String notes = item['notes'] ?? '';
        final String date = item['date'] ?? '';
        final int id = item['id'] is num ? (item['id'] as num).toInt() : (int.tryParse(item['id']?.toString() ?? '0') ?? 0);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.local_gas_station, color: Colors.orange.shade900),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vType.isNotEmpty ? '$vNo ($vType)' : vNo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${liters.toStringAsFixed(1)} L',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade900),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (driver.isNotEmpty) Text('Driver: $driver', style: const TextStyle(fontSize: 12)),
                      if (hours.isNotEmpty) Text('Hrs/Km: $hours', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (notes.isNotEmpty) Text('Notes: $notes', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                  onPressed: () {
                    showDispenseFuelDialog(context, data, existingIssue: item);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    _confirmDeleteIssue(context, data, id, vNo, liters);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchasesList(List<Map<String, dynamic>> purchases, DataProvider data) {
    if (purchases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 54, color: Colors.grey),
            SizedBox(height: 12),
            Text('No bulk purchases recorded', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final item = purchases[index];
        double qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        if (qty <= 0) qty = double.tryParse(item['liters']?.toString() ?? '0') ?? 0;
        final double amount = data.parseAmount(item['amount']);
        final String supplier = item['supplier'] ?? 'Bulk Fuel Supplier';
        final String title = item['title'] ?? 'Bulk Storage Tank Purchase';
        final String date = item['date'] ?? '';
        final String? rateStr = item['rate']?.toString();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.add_shopping_cart, color: Colors.green.shade900),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    supplier,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₹${amount.toInt()}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Purchased: ${qty.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      if (rateStr != null && rateStr.isNotEmpty)
                        Text('Rate: ₹$rateStr/L', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))
                      else if (qty > 0 && amount > 0)
                        Text('Rate: ₹${(amount / qty).toStringAsFixed(2)}/L', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ],
                  ),
                  Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteIssue(BuildContext context, DataProvider data, int id, String vNo, double liters) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Delete fuel issue of ${liters.toStringAsFixed(1)} L for $vNo?\nThis will refund ${liters.toStringAsFixed(1)} L back to Storage Tank stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              data.deleteFuelIssue(id);
            },
            child: const Text('DELETE & REFUND'),
          ),
        ],
      ),
    );
  }
}
