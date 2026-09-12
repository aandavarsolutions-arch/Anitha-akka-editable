import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/status_chip.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import 'vehicle_summary_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Set default date range to current month if not set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = Provider.of<DataProvider>(context, listen: false);
      if (data.selectedDateRange == null) {
        final now = DateTime.now();
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        data.setSelectedDateRange(DateTimeRange(start: firstDay, end: lastDay));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatShortAmount(double val) {
    bool isNegative = val < 0;
    double absVal = val.abs();
    String prefix = isNegative ? '-₹' : '₹';
    return '$prefix${absVal.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('DASHBOARD'),
        actions: const [DevBrandingBadge()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.orangeAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'INCOME VS EXPENSE'),
            Tab(text: 'CASH RECEIVED VS SETTLED'),
            Tab(text: 'DAILY REPORT'),
            Tab(text: 'VEHICLE SUMMARY'),
          ],
        ),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildSalesVsExpenseView(data),
              _buildCashReceivedVsSettledView(data),
              _buildDailyVehicleReportView(data),
              const VehicleSummaryScreen(isEmbedded: true),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: SALES VS EXPENSE (Matching User Reference Image)
  // ---------------------------------------------------------------------------
  Widget _buildSalesVsExpenseView(DataProvider data) {
    // Gather Material Sales Breakdown first
    final Map<String, double> materialBreakdown = {};
    for (var v in data.vehicles) {
      final matName = (v['material_name'] ?? '').toString().trim();
      final matAmt = data.parseAmount(v['material_amount']);
      final totalAmt = data.parseAmount(v['total']);
      final rentAmt = data.parseAmount(v['rent_amount']);
      final tripSales = totalAmt > 0 ? totalAmt : (matAmt > 0 ? matAmt : rentAmt);

      if (matName.isNotEmpty && matAmt > 0) {
        materialBreakdown[matName] = (materialBreakdown[matName] ?? 0) + (totalAmt > 0 ? totalAmt : matAmt);
      } else if (tripSales > 0) {
        final vType = (v['type'] ?? 'Vehicle Hire').toString().trim();
        materialBreakdown['Vehicle ($vType)'] = (materialBreakdown['Vehicle ($vType)'] ?? 0) + tripSales;
      }
    }
    
    // Add Site Income Categories if available
    for (var inc in data.siteIncome) {
      final cat = (inc['category'] ?? inc['title'] ?? 'Other Income').toString().trim();
      final amt = data.parseAmount(inc['amount']);
      if (amt > 0) {
        materialBreakdown[cat] = (materialBreakdown[cat] ?? 0) + amt;
      }
    }

    double sales = materialBreakdown.values.fold(0.0, (sum, val) => sum + val);
    if (sales == 0) {
      sales = data.totalSalesValue > 0 ? data.totalSalesValue : data.totalIncomeValue;
      if (sales > 0 && materialBreakdown.isEmpty) {
        materialBreakdown['General Sales'] = sales;
      }
    }

    final double expense = data.totalExpenseValue;
    final double profit = sales - expense;

    final double maxBreakdownVal = materialBreakdown.values.fold(1.0, (prev, element) => element > prev ? element : prev);

    // Gather Expense Breakdown
    final Map<String, double> expenseBreakdown = Map<String, double>.from(data.expenseBreakdown);
    if (expenseBreakdown.isEmpty && expense > 0) {
      expenseBreakdown['General Expense'] = expense;
    }
    final double maxExpenseBreakdownVal = expenseBreakdown.values.fold(1.0, (prev, element) => element > prev ? element : prev);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Filter Bar
          _buildDateFilter(data),
          const SizedBox(height: 16),

          // Top 3 Summary Cards Row
          Row(
            children: [
              // 1. TOTAL INCOME (Bright Green)
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL INCOME',
                  value: _formatShortAmount(sales),
                  color: const Color(0xFF42B883),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(width: 10),

              // 2. TOTAL EXPENSE (Coral Red)
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL EXPENSE',
                  value: _formatShortAmount(expense),
                  color: const Color(0xFFEF5350),
                  icon: Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 10),

              // 3. NET PROFIT (Dark Green)
              Expanded(
                child: _buildMetricCard(
                  title: 'NET PROFIT',
                  value: '₹${profit.toInt()}',
                  color: const Color(0xFF2E7D32),
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title 1
          const Text(
            'VISUALIZATION (INCOME VS EXPENSE)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF37474F),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Bar Chart Comparison Card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    'Income vs Expense Comparison',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: (sales > expense ? sales : expense) * 1.25 == 0 ? 100 : (sales > expense ? sales : expense) * 1.25,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Colors.blueGrey.shade800,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              String label = groupIndex == 0 ? 'Income' : 'Expenses';
                              return BarTooltipItem(
                                '$label\n₹${rod.toY.toInt()}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Income',
                                          style: TextStyle(color: Color(0xFF42B883), fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${sales.toInt()}',
                                          style: const TextStyle(color: Color(0xFF42B883), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (value.toInt() == 1) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Expenses',
                                          style: TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${expense.toInt()}',
                                          style: const TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 44,
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: sales,
                                color: const Color(0xFF42B883),
                                width: 36,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: expense,
                                color: const Color(0xFFEF5350),
                                width: 36,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section Title 2
          const Text(
            'INCOME BREAKDOWN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF37474F),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown Card List for Sales
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: materialBreakdown.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF42B883),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Income (${entry.key})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Text(
                          '₹${entry.value.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section Title 3: EXPENSE BREAKDOWN
          const Text(
            'EXPENSE BREAKDOWN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF37474F),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown Card List for Expenses
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: expenseBreakdown.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF5350),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Expense (${entry.key})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Text(
                          '₹${entry.value.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: CASH RECEIVED VS SETTLED
  // ---------------------------------------------------------------------------
  Widget _buildCashReceivedVsSettledView(DataProvider data) {
    final range = data.selectedDateRange;

    // Filtered lists based on Date Range
    List<Map<String, dynamic>> receivedItems = [];
    List<Map<String, dynamic>> settledItems = [];

    double totalReceived = 0.0;
    double totalSettled = 0.0;

    // 1. Gather Cash Received (From Customers / Vehicle Jobs / Site Income)
    for (var v in data.vehicles) {
      final amt = data.parseAmount(v['paid']);
      if (amt > 0) {
        final dt = _parseDate(v['date']);
        if (range != null && dt != null) {
          final check = DateTime(dt.year, dt.month, dt.day);
          final start = DateTime(range.start.year, range.start.month, range.start.day);
          final end = DateTime(range.end.year, range.end.month, range.end.day);
          if (check.isBefore(start) || check.isAfter(end)) continue;
        }
        totalReceived += amt;
        receivedItems.add({
          'title': (v['customer'] != null && v['customer'].toString().trim().isNotEmpty) ? v['customer'] : (v['number'] ?? 'Vehicle Job'),
          'subtitle': v['date'] ?? 'Today',
          'amount': amt,
        });
      }
    }

    for (var inc in data.siteIncome) {
      final amt = data.parseAmount(inc['received'] ?? inc['amount']);
      if (amt > 0) {
        final dt = _parseDate(inc['date']);
        if (range != null && dt != null) {
          final check = DateTime(dt.year, dt.month, dt.day);
          final start = DateTime(range.start.year, range.start.month, range.start.day);
          final end = DateTime(range.end.year, range.end.month, range.end.day);
          if (check.isBefore(start) || check.isAfter(end)) continue;
        }
        totalReceived += amt;
        receivedItems.add({
          'title': (inc['title'] ?? inc['category'] ?? 'Site Income').toString(),
          'subtitle': inc['date'] ?? 'Today',
          'amount': amt,
        });
      }
    }

    for (var cp in data.customerPayments) {
      final isDisc = cp['type']?.toString() == 'Discount' || (cp['notes'] ?? '').toString().toLowerCase().contains('discount');
      if (isDisc) continue;

      final amt = data.parseAmount(cp['amount']);
      if (amt > 0) {
        final dt = _parseDate(cp['date']);
        if (range != null && dt != null) {
          final check = DateTime(dt.year, dt.month, dt.day);
          final start = DateTime(range.start.year, range.start.month, range.start.day);
          final end = DateTime(range.end.year, range.end.month, range.end.day);
          if (check.isBefore(start) || check.isAfter(end)) continue;
        }
        totalReceived += amt;
        receivedItems.add({
          'title': (cp['customer_name'] ?? cp['customer'] ?? 'Customer Payment').toString(),
          'subtitle': 'Customer Payment • ${cp['date'] ?? 'Today'}',
          'amount': amt,
        });
      }
    }

    // 2. Gather Cash Settled (Expenses / Supplier Payments / Driver Payments / Bunk / Mechanic / Tea)
    for (var exp in data.siteExpenses) {
      final supplier = (exp['supplier'] ?? '').toString().trim();
      final title = (exp['title'] ?? '').toString().trim();
      bool isInternalIssue = supplier == 'Storage Tank' || 
                             title.contains('Tank Dispense') || 
                             exp['is_internal_issue'] == 1 || 
                             exp['is_internal_issue'] == '1';
      if (isInternalIssue) continue;

      final amt = data.parseAmount(exp['paid'] ?? exp['amount']);
      if (amt > 0) {
        final dt = _parseDate(exp['date']);
        if (range != null && dt != null) {
          final check = DateTime(dt.year, dt.month, dt.day);
          final start = DateTime(range.start.year, range.start.month, range.start.day);
          final end = DateTime(range.end.year, range.end.month, range.end.day);
          if (check.isBefore(start) || check.isAfter(end)) continue;
        }
        totalSettled += amt;
        final cat = (exp['category'] ?? 'Expense').toString();
        final date = (exp['date'] ?? 'Today').toString();
        final vNo = (exp['vehicle_no'] ?? '').toString().trim();

        String itemTitle = supplier;
        if (itemTitle.isEmpty) {
          String cleanTitle = title;
          cleanTitle = cleanTitle.replaceAll(RegExp(r'^(Fuel|Repair|Maintenance):\s*', caseSensitive: false), '').trim();
          if (cleanTitle.isNotEmpty) {
            itemTitle = cleanTitle;
          } else {
            String rawTitle = title.replaceAll(':', '').trim();
            if (rawTitle.isNotEmpty) {
              itemTitle = rawTitle;
            } else {
              itemTitle = cat;
            }
          }
        }

        String subtitleText = '$cat • $date';
        if (vNo.isNotEmpty) {
          subtitleText = '$cat ($vNo) • $date';
        }

        settledItems.add({
          'title': itemTitle,
          'subtitle': subtitleText,
          'amount': amt,
        });
      }
    }

    for (var sp in data.supplierPayments) {
      final type = (sp['type'] ?? '').toString();
      if (type == 'Discount') continue;

      final amt = data.parseAmount(sp['amount']);
      if (amt > 0) {
        final dt = _parseDate(sp['date']);
        if (range != null && dt != null) {
          final check = DateTime(dt.year, dt.month, dt.day);
          final start = DateTime(range.start.year, range.start.month, range.start.day);
          final end = DateTime(range.end.year, range.end.month, range.end.day);
          if (check.isBefore(start) || check.isAfter(end)) continue;
        }

        String sName = (sp['supplier'] ?? sp['supplier_name'] ?? '').toString().trim();
        if (sName.isEmpty && sp['supplier_id'] != null) {
          final sId = sp['supplier_id'].toString().trim();
          final match = data.suppliers.firstWhere((s) => s['id']?.toString().trim() == sId, orElse: () => {});
          if (match.isNotEmpty) {
            sName = (match['name'] ?? '').toString().trim();
          }
        }
        if (sName.isEmpty) sName = 'Supplier';

        totalSettled += amt;
        final date = (sp['date'] ?? 'Today').toString();
        settledItems.add({
          'title': sName,
          'subtitle': 'Supplier Settlement • $date',
          'amount': amt,
        });
      }
    }

    for (var dp in data.driverPayments) {
      if ((dp['type'] ?? 'Payment') == 'Payment') {
        final mode = (dp['mode'] ?? '').toString().trim().toLowerCase();
        final isDeduct = mode == 'deduct from advance' || mode.contains('deduct') || mode.contains('கழித்தல்');
        if (isDeduct) continue;
        final amt = data.parseAmount(dp['amount']);
        if (amt > 0) {
          final dt = _parseDate(dp['date']);
          if (range != null && dt != null) {
            final check = DateTime(dt.year, dt.month, dt.day);
            final start = DateTime(range.start.year, range.start.month, range.start.day);
            final end = DateTime(range.end.year, range.end.month, range.end.day);
            if (check.isBefore(start) || check.isAfter(end)) continue;
          }
          totalSettled += amt;
          final date = (dp['date'] ?? 'Today').toString();
          
          String driverName = (dp['driver_name'] ?? '').toString().trim();
          if (driverName.isEmpty) {
            final driverId = (dp['driver_id'] ?? '').toString().trim();
            if (driverId.isNotEmpty) {
              final dObj = data.allDrivers.firstWhere(
                (d) => (d['id'] ?? '').toString().trim() == driverId,
                orElse: () => {},
              );
              if (dObj.isNotEmpty && dObj['name'] != null && dObj['name'].toString().trim().isNotEmpty) {
                driverName = dObj['name'].toString().trim();
              }
            }
          }
          if (driverName.isEmpty) {
            driverName = 'Driver Payment';
          }

          settledItems.add({
            'title': driverName,
            'subtitle': 'Driver Salary/Advance • $date',
            'amount': amt,
          });
        }
      }
    }

    final double outstanding = (totalReceived - totalSettled) >= 0 ? (totalReceived - totalSettled) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Filter Bar
          _buildDateFilter(data),
          const SizedBox(height: 16),

          // Top 3 Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'CASH RECEIVED',
                  value: _formatShortAmount(totalReceived),
                  color: const Color(0xFF42B883),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'CASH SETTLED',
                  value: _formatShortAmount(totalSettled),
                  color: const Color(0xFFFF9800),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'NET CASH',
                  value: '₹${outstanding.toInt()}',
                  color: const Color(0xFFEF5350),
                  icon: Icons.pending_actions_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title 1: Bar Chart
          const Text(
            'VISUALIZATION (CASH FLOW)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF37474F),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    'Cash Received vs Cash Settled Comparison',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: (totalReceived > totalSettled ? totalReceived : totalSettled) * 1.25 == 0 ? 100 : (totalReceived > totalSettled ? totalReceived : totalSettled) * 1.25,
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Cash Received (In)',
                                      style: TextStyle(color: Color(0xFF009688), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  );
                                } else if (value.toInt() == 1) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Cash Settled (Out)',
                                      style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 28,
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: totalReceived,
                                color: const Color(0xFF009688),
                                width: 36,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: totalSettled,
                                color: const Color(0xFFFF9800),
                                width: 36,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section Title 2: Cash Received From
          const Text(
            'CASH RECEIVED FROM (WHO PAID US)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF37474F),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: receivedItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No cash received entries for selected range', style: TextStyle(color: Colors.grey))),
                    )
                  : Column(
                      children: receivedItems.map((item) {
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFE0F2F1),
                            child: const Icon(Icons.arrow_downward_rounded, size: 18, color: Color(0xFF009688)),
                          ),
                          title: Text(
                            item['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            item['subtitle'],
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          trailing: Text(
                            '₹${(item['amount'] as double).toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF009688),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Section Title 3: Cash Settled To
          const Text(
            'CASH SETTLED TO (WHO WE PAID)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF37474F),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: settledItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No cash settled entries for selected range', style: TextStyle(color: Colors.grey))),
                    )
                  : Column(
                      children: settledItems.map((item) {
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFFBE9E7),
                            child: const Icon(Icons.arrow_upward_rounded, size: 18, color: Color(0xFFFF5722)),
                          ),
                          title: Text(
                            item['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            item['subtitle'],
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          trailing: Text(
                            '₹${(item['amount'] as double).toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFFFF5722),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter(DataProvider data) {
    return GestureDetector(
      onTap: () => data.selectDateRange(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: JarvisTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.selectedDateRange != null ? data.formattedSelectedDate : 'Select Date Range',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
            if (data.selectedDateRange != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: data.clearDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: DAILY VEHICLE REPORT (Preserved)
  // ---------------------------------------------------------------------------
  Widget _buildDailyVehicleReportView(DataProvider data) {
    final range = data.selectedDateRange;
    final dateRangeStr = range != null
        ? '${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}'
        : 'All Dates';

    List<Map<String, dynamic>> reportRows = [];
    int sno = 1;

    final sortedVehicles = List<Map<String, dynamic>>.from(data.vehicles);
    sortedVehicles.sort((a, b) {
      final da = _parseDate(a['date']) ?? DateTime(2000);
      final db = _parseDate(b['date']) ?? DateTime(2000);
      return db.compareTo(da);
    });

    for (var v in sortedVehicles) {
      final dt = _parseDate(v['date']);
      if (range != null && dt != null) {
        final check = DateTime(dt.year, dt.month, dt.day);
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        if (check.isBefore(start) || check.isAfter(end)) continue;
      }

      final custName = (v['customer'] ?? '').toString().trim();
      String place = (v['site'] ?? '').toString().trim();
      String phoneNo = '0';

      if (custName.isNotEmpty) {
        try {
          final custObj = data.customers.firstWhere(
            (c) => (c['name'] ?? '').toString().toLowerCase().trim() == custName.toLowerCase(),
            orElse: () => {},
          );
          if (custObj.isNotEmpty) {
            if (place.isEmpty || place.toLowerCase() == 'general') {
              if (custObj['address'] != null && custObj['address'].toString().trim().isNotEmpty) {
                place = custObj['address'].toString().trim();
              }
            }
            if (custObj['phone'] != null && custObj['phone'].toString().trim().isNotEmpty) {
              phoneNo = custObj['phone'].toString().trim();
            }
          }
        } catch (_) {}
      }
      if (place.isEmpty) place = 'General';

      String dieselStr = '0';
      if (v['material_name'] != null &&
          (v['material_name'].toString().toLowerCase().contains('diesel') ||
           v['material_name'].toString().toLowerCase().contains('fuel'))) {
        dieselStr = (v['quantity'] ?? v['material_amount'] ?? '0').toString();
      } else {
        final vNo = (v['number'] ?? '').toString().toLowerCase().trim();
        final vDate = (v['date'] ?? '').toString();
        final matchingFuel = data.siteExpenses.where((exp) {
          final expVNo = (exp['vehicle_no'] ?? '').toString().toLowerCase().trim();
          final expDate = (exp['date'] ?? '').toString();
          return expVNo.isNotEmpty && expVNo == vNo && expDate == vDate && (exp['liters'] != null || exp['quantity'] != null);
        }).toList();

        if (matchingFuel.isNotEmpty) {
          double totalLiters = 0;
          for (var f in matchingFuel) {
            totalLiters += double.tryParse(f['liters']?.toString() ?? f['quantity']?.toString() ?? '0') ?? 0;
          }
          if (totalLiters > 0) dieselStr = totalLiters.toInt().toString();
        }
      }

      String durationStr = (v['duration'] ?? v['quantity'] ?? '1').toString().trim();
      final rateTypeStr = (v['rate_type'] ?? '').toString().trim();
      if (rateTypeStr.isNotEmpty && !durationStr.toLowerCase().contains(rateTypeStr.toLowerCase())) {
        durationStr = '$durationStr $rateTypeStr';
      }

      final paidAmt = data.parseAmount(v['paid']);
      String statusStr = '0';
      if (paidAmt > 0) {
        statusStr = paidAmt.toInt().toString();
      } else {
        final bal = data.parseAmount(v['balance']);
        if (bal <= 0) statusStr = 'Paid';
      }

      reportRows.add({
        's_no': sno++,
        'vehicle': (v['type'] ?? 'Vehicle').toString(),
        'vehicle_no': (v['number'] ?? '').toString(),
        'driver': (v['driver'] ?? 'N/A').toString(),
        'bill_no': (v['bill_no'] != null && v['bill_no'].toString().trim().isNotEmpty) ? v['bill_no'].toString() : '0',
        'date': (v['date'] ?? '').toString(),
        'party_name': custName.isNotEmpty ? custName : 'N/A',
        'place': place,
        'phone_no': phoneNo,
        'time': durationStr.isNotEmpty ? durationStr : '-',
        'diesel': dieselStr,
        'status': statusStr,
        'details': (v['manual_desc'] != null && v['manual_desc'].toString().trim().isNotEmpty) ? v['manual_desc'].toString() : '0',
      });
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDateRange: data.selectedDateRange ?? DateTimeRange(
                        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
                        end: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      data.setSelectedDateRange(picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month, size: 18, color: JarvisTheme.primary),
                  label: Text(
                    dateRangeStr,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Export Excel',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade800,
                ),
                onPressed: reportRows.isEmpty ? null : () {
                  ExcelService.generateDailyVehicleReportExcel(
                    reportRows: reportRows,
                    dateRangeTitle: dateRangeStr,
                    businessName: 'Aandavar Solutions',
                  );
                },
                icon: const Icon(Icons.table_chart, size: 20),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Export PDF',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade800,
                ),
                onPressed: reportRows.isEmpty ? null : () {
                  PdfService().generateDailyVehicleReportPdf(
                    reportRows: reportRows,
                    dateRangeTitle: dateRangeStr,
                    businessName: 'Aandavar Solutions',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 20),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Share & Copy Report Summary',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade800,
                ),
                onPressed: reportRows.isEmpty ? null : () async {
                  const String busName = 'Aandavar Solutions';
                  String textSummary = "*$busName*\n*DAILY VEHICLE REPORT*\nPeriod: $dateRangeStr\n\n";
                  for (var r in reportRows) {
                    textSummary += "${r['s_no']}. ${r['vehicle']} (${r['vehicle_no']}) | ${r['driver']} | ${r['party_name']} (${r['place']}) | Time: ${r['time']} | Status: ${r['status']}\n";
                  }
                  await Clipboard.setData(ClipboardData(text: textSummary));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 Report summary copied to clipboard! Open WhatsApp and paste directly.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }

                  await PdfService().generateDailyVehicleReportPdf(
                    reportRows: reportRows,
                    dateRangeTitle: dateRangeStr,
                    businessName: busName,
                    share: true,
                    context: context,
                  );
                },
                icon: const Icon(Icons.share, size: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: reportRows.isEmpty
              ? const Center(
                  child: Text('No daily vehicle entries found for selected date range', style: TextStyle(color: Colors.grey)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Table(
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        columnWidths: const {
                          0: FixedColumnWidth(48),   // S.No
                          1: FixedColumnWidth(90),   // Vehicle
                          2: FixedColumnWidth(110),  // Vehicle No
                          3: FixedColumnWidth(110),  // Driver
                          4: FixedColumnWidth(64),   // Bill No
                          5: FixedColumnWidth(95),   // Date
                          6: FixedColumnWidth(140),  // Party Name
                          7: FixedColumnWidth(120),  // Place
                          8: FixedColumnWidth(100),  // Phone No
                          9: FixedColumnWidth(80),   // Time
                          10: FixedColumnWidth(75),  // Diesel
                          11: FixedColumnWidth(120), // Status
                          12: FixedColumnWidth(130), // Details
                        },
                        border: TableBorder.all(color: Colors.grey.shade400, width: 0.8),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xFFFFFF00)),
                            children: const [
                              _TableHeaderCell('S.No'),
                              _TableHeaderCell('Vehicle'),
                              _TableHeaderCell('Vehicle No'),
                              _TableHeaderCell('Driver'),
                              _TableHeaderCell('Bill No'),
                              _TableHeaderCell('Date'),
                              _TableHeaderCell('Party Name'),
                              _TableHeaderCell('Place'),
                              _TableHeaderCell('Phone No'),
                              _TableHeaderCell('Time'),
                              _TableHeaderCell('Diesel'),
                              _TableHeaderCell('Status'),
                              _TableHeaderCell('Details'),
                            ],
                          ),
                          ...reportRows.map((row) {
                            return TableRow(
                              decoration: BoxDecoration(
                                color: row['s_no'] % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                              ),
                              children: [
                                _TableCellText(row['s_no'].toString(), align: TextAlign.center),
                                _TableCellText(row['vehicle'].toString()),
                                _TableCellText(row['vehicle_no'].toString(), isBold: true),
                                _TableCellText(row['driver'].toString()),
                                _TableCellText(row['bill_no'].toString(), align: TextAlign.center),
                                _TableCellText(row['date'].toString(), align: TextAlign.center),
                                _TableCellText(row['party_name'].toString()),
                                _TableCellText(row['place'].toString()),
                                _TableCellText(row['phone_no'].toString(), align: TextAlign.center),
                                _TableCellText(row['time'].toString(), align: TextAlign.center),
                                _TableCellText(row['diesel'].toString(), align: TextAlign.center),
                                _TableCellText(row['status'].toString(), isStatus: true),
                                _TableCellText(row['details'].toString()),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null || dateStr is! String) return null;
    final now = DateTime.now();
    final lower = dateStr.toLowerCase().trim();
    
    if (lower == 'today' || lower == 'just now') return now;
    if (lower == 'yesterday') return now.subtract(const Duration(days: 1));
    
    try {
      if (dateStr.length > 8) {
         return DateFormat('d MMM yyyy').parse(dateStr);
      } else {
         final d = DateFormat('d MMM').parse(dateStr);
         return DateTime(now.year, d.month, d.day);
      }
    } catch (e) {
      return null;
    }
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableCellText extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool isBold;
  final bool isStatus;

  const _TableCellText(
    this.text, {
    this.align = TextAlign.left,
    this.isBold = false,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    Color txtColor = Colors.black87;
    if (isStatus && text.contains('AR-Cash')) {
      txtColor = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold || isStatus ? FontWeight.bold : FontWeight.normal,
          color: txtColor,
        ),
        textAlign: align,
      ),
    );
  }
}
