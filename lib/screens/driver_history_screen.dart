import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../app_config.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import 'add_vehicle_payment_screen.dart';
import 'package:pdf/widgets.dart' as pw;

class DriverHistoryScreen extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DriverHistoryScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isDateInRange(String? dateStr) {
    if (_selectedDateRange == null) return true;
    if (dateStr == null) return true;
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
             date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    } catch (_) { return false; }
  }

  List<Map<String, dynamic>> _getFormattedLedgerRows(
    List<Map<String, dynamic>> paid, 
    List<Map<String, dynamic>> work,
    DataProvider data,
    Map<String, dynamic> driver,
  ) {
    Map<String, Map<String, dynamic>> attendanceMap = {};
    for (var w in work) {
      if (w['type'] == 'Attendance' && w['date'] != null) {
        attendanceMap[w['date'].toString()] = w;
      }
    }

    Map<String, List<Map<String, dynamic>>> paymentsMap = {};
    for (var p in paid) {
      final date = p['date']?.toString() ?? '';
      if (date.isNotEmpty) {
        if (!paymentsMap.containsKey(date)) paymentsMap[date] = [];
        paymentsMap[date]!.add(p);
      }
    }

    Map<String, Map<String, dynamic>> salaryMap = {};
    for (var w in work) {
      if ((w['type'] == 'Work' || w['status'] == 'Salary') && w['date'] != null) {
        salaryMap[w['date'].toString()] = w;
      }
    }

    final isDailyDriver = (driver['type'] ?? 'Monthly') == 'Daily';
    final dailyWageRate = data.parseAmount(driver['salary'] ?? driver['earnings']);

    DateTime? joiningDate;
    if (driver['date'] != null && driver['date'].toString().trim().isNotEmpty) {
      try {
        joiningDate = DateFormat('dd MMM yyyy').parse(driver['date'].toString().trim());
      } catch (_) {}
    }

    DateTime endDate = DateTime.now();
    DateTime startDate;

    if (_selectedDateRange != null) {
      startDate = _selectedDateRange!.start;
      endDate = _selectedDateRange!.end;
    } else {
      DateTime minDate = joiningDate ?? DateTime(endDate.year, endDate.month, 1);
      
      for (var w in work) {
        if (w['date'] != null) {
          try {
            DateTime d = DateFormat('dd MMM yyyy').parse(w['date']);
            if (w['id'] != null && !w['id'].toString().startsWith('M-SAL-')) {
              if (d.isBefore(minDate)) minDate = d;
            }
          } catch (_) {}
        }
      }
      for (var p in paid) {
        if (p['date'] != null) {
          try {
            DateTime d = DateFormat('dd MMM yyyy').parse(p['date']);
            if (d.isBefore(minDate)) minDate = d;
          } catch (_) {}
        }
      }

      startDate = minDate;
    }

    List<Map<String, dynamic>> resultList = [];
    DateTime curDate = startDate;

    while (!curDate.isAfter(endDate)) {
      final dateStr = DateFormat('dd MMM yyyy').format(curDate);
      
      final attItem = attendanceMap[dateStr];
      final salItem = salaryMap[dateStr];
      final payList = paymentsMap[dateStr] ?? [];

      final isBeforeJoining = joiningDate != null && 
          DateTime(curDate.year, curDate.month, curDate.day)
              .isBefore(DateTime(joiningDate.year, joiningDate.month, joiningDate.day));

      if (isBeforeJoining && attItem == null && salItem == null && payList.isEmpty) {
        curDate = curDate.add(const Duration(days: 1));
        continue;
      }

      String attStatus = 'Absent';
      if (attItem != null) {
        attStatus = attItem['status']?.toString() ?? 'Present';
      }

      double earningsAmt = 0;
      if (salItem != null && !isBeforeJoining) {
        earningsAmt = data.parseAmount(salItem['amount']);
      } else if (attStatus == 'Present') {
        if (attItem != null) {
          earningsAmt = data.parseAmount(attItem['amount']);
        } else if (isDailyDriver && dailyWageRate > 0) {
          earningsAmt = dailyWageRate;
        }
      }

      if (salItem != null && !isBeforeJoining) {
        final displayAtt = 'Salary Credit ($attStatus)';
        if (payList.isNotEmpty) {
          for (int i = 0; i < payList.length; i++) {
            final p = payList[i];
            final pAmt = data.parseAmount(p['amount']);
            final pMode = (p['mode'] != null && p['mode'].toString().trim().isNotEmpty) ? p['mode'].toString().trim() : 'Cash';
            resultList.add({
              'date': dateStr,
              'attendance': (i == 0) ? displayAtt : '-',
              'mode': pMode,
              'earnings': (i == 0) ? earningsAmt : 0.0,
              'paid': pAmt,
              'hasPayment': true,
              'rawAttStatus': attStatus,
            });
          }
        } else {
          resultList.add({
            'date': dateStr,
            'attendance': displayAtt,
            'mode': '-',
            'earnings': earningsAmt,
            'paid': 0.0,
            'hasPayment': false,
            'rawAttStatus': attStatus,
          });
        }
      } else {
        if (payList.isNotEmpty) {
          for (int i = 0; i < payList.length; i++) {
            final p = payList[i];
            final pAmt = data.parseAmount(p['amount']);
            final pMode = (p['mode'] != null && p['mode'].toString().trim().isNotEmpty) ? p['mode'].toString().trim() : 'Cash';

            resultList.add({
              'date': dateStr,
              'attendance': (i == 0) ? attStatus : '-',
              'mode': pMode,
              'earnings': (i == 0) ? earningsAmt : 0.0,
              'paid': pAmt,
              'hasPayment': true,
              'rawAttStatus': attStatus,
            });
          }
        } else if (!isBeforeJoining) {
          resultList.add({
            'date': dateStr,
            'attendance': attStatus,
            'mode': '-',
            'earnings': earningsAmt,
            'paid': 0.0,
            'hasPayment': false,
            'rawAttStatus': attStatus,
          });
        }
      }

      curDate = curDate.add(const Duration(days: 1));
    }

    // Sort: Ascending ONLY when Date Range is selected; Default view: Descending (newest date at top)
    resultList.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        if (_selectedDateRange != null) {
          return da.compareTo(db);
        } else {
          return db.compareTo(da);
        }
      } catch (_) { return 0; }
    });

    return resultList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DRIVER LEDGER', style: TextStyle(fontSize: 14)),
            Text(widget.driverName, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
            if (_selectedDateRange != null)
              IconButton(
                icon: const Icon(Icons.highlight_off),
                onPressed: () => setState(() => _selectedDateRange = null),
              ),
            IconButton(
              icon: Icon(Icons.date_range, color: _selectedDateRange != null ? JarvisTheme.secondary : null),
              onPressed: () async {
                 final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: _selectedDateRange,
                 );
                 if (picked != null) setState(() => _selectedDateRange = picked);
              },
            ),
             IconButton(
                icon: const Icon(Icons.share, color: Colors.green),
                onPressed: () => _generatePdf(context, share: true),
                tooltip: 'Share via WhatsApp',
             ),
             IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _generatePdf(context, save: true),
                tooltip: 'Save as PDF',
            ),
            IconButton(
              icon: const Icon(Icons.grid_on),
              onPressed: () => _generateExcel(context),
              tooltip: 'Export as Excel',
            ),
            Consumer<DataProvider>(
              builder: (context, provider, _) {
                final driver = provider.drivers.firstWhere((d) => d['id'].toString() == widget.driverId.toString(), orElse: () => {});
                if (driver.isNotEmpty && driver['type'] == 'Monthly' && !AppConfig.isReadOnly) {
                  return IconButton(
                    icon: const Icon(Icons.add_card, color: Colors.tealAccent),
                    onPressed: () => _showCreditSalaryDialog(context, driver),
                    tooltip: 'Credit Month Salary',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const DevBrandingBadge()
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: JarvisTheme.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ALL LEDGER'),
            Tab(text: 'PAYMENTS'),
            Tab(text: 'WORK LOGS'),
          ],
        ),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          final driver = data.drivers.firstWhere((d) => d['id'].toString() == widget.driverId.toString(), orElse: () => {});

          return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: data.getDriverLedgerCategorized(widget.driverId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData) return const Center(child: Text('No Data found'));

              final paid = snapshot.data!['paid']!.where((item) => _isDateInRange(item['date'])).toList();
              final allWork = snapshot.data!['work']!.where((item) => _isDateInRange(item['date'])).toList();
              final allCombined = _getFormattedLedgerRows(paid, allWork, data, driver);

              // Calculate Present and Absent counts
              Set<String> uniquePresentDates = {};
              Set<String> uniqueAbsentDates = {};

              for (var item in allCombined) {
                final att = item['attendance']?.toString() ?? '-';
                final rawAtt = item['rawAttStatus']?.toString() ?? '';
                final dateStr = item['date']?.toString() ?? '';

                if (att.contains('Present') || rawAtt == 'Present') {
                  uniquePresentDates.add(dateStr);
                } else if (att.contains('Absent') || rawAtt == 'Absent') {
                  if (!uniquePresentDates.contains(dateStr)) {
                    uniqueAbsentDates.add(dateStr);
                  }
                }
              }

              final presentCount = uniquePresentDates.length;
              final absentCount = uniqueAbsentDates.length;

              final vehicleWorkLogs = allWork.where((item) => item['type'] == 'VehicleWork' || item['status'] == 'Vehicle Duty').toList();

              return Column(
                children: [
                  // Top Summary Cards (Present Days & Absent Days)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                const Text('Present Days', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('$presentCount Days', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                const Text('Absent Days', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('$absentCount Days', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFormattedList(allCombined),
                        _buildRawList(paid, true, data),
                        _buildRawList(vehicleWorkLogs, false, data),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFormattedList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Center(child: Text('No records in this range', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final attStatus = item['attendance']?.toString() ?? '-';
        final modeStr = item['mode']?.toString() ?? '-';
        final paidAmt = (item['paid'] as num).toDouble();
        final earningsAmt = (item['earnings'] as num).toDouble();
        final hasPayment = item['hasPayment'] as bool;

        Color badgeColor = Colors.grey;
        if (attStatus.contains('Present')) badgeColor = Colors.green;
        if (attStatus.contains('Absent')) badgeColor = Colors.red;
        if (attStatus.contains('Salary Credit')) badgeColor = Colors.blue;

        String amtDisplay = '₹0';
        Color amtColor = Colors.grey;

        if (hasPayment && paidAmt > 0) {
          amtDisplay = '₹${paidAmt.toInt()}';
          amtColor = Colors.green;
        } else if (earningsAmt > 0) {
          amtDisplay = '₹${earningsAmt.toInt()}';
          amtColor = Colors.green;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              final data = Provider.of<DataProvider>(context, listen: false);
              _showWorkLogInfoDialog(context, item, data);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: (hasPayment ? Colors.green : (badgeColor != Colors.grey ? badgeColor : Colors.green)).withValues(alpha: 0.1),
                        child: Icon(
                          hasPayment ? Icons.payment : (attStatus.contains('Absent') ? Icons.close : Icons.check_circle_outline), 
                          color: hasPayment ? Colors.green : (badgeColor != Colors.grey ? badgeColor : Colors.green), 
                          size: 18
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attStatus, 
                            style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 13)
                          ),
                          const SizedBox(height: 2),
                          Text('Date: ${item['date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Salary: ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          Text(
                            '₹${earningsAmt.toInt()}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: earningsAmt > 0 ? Colors.blue[700] : Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (modeStr != '-')
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                modeStr,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                              ),
                            ),
                          Text('Amount Paid: ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          Text(
                            '₹${paidAmt.toInt()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14, 
                              color: paidAmt > 0 ? Colors.green[700] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRawList(List<Map<String, dynamic>> items, bool isPaid, DataProvider data) {
    if (items.isEmpty) return const Center(child: Text('No records in this range', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final typeStr = item['type']?.toString() ?? '';
        final statusStr = item['status']?.toString() ?? (isPaid ? 'Paid' : 'Present');
        final modeStr = item['mode']?.toString() ?? '-';
        final rawAmt = data.parseAmount(item['amount']);

        Color themeColor = Colors.green;
        IconData leadingIcon = Icons.check_circle_outline;

        if (isPaid) {
          themeColor = Colors.green;
          leadingIcon = Icons.payment;
        } else if (typeStr == 'VehicleWork' || statusStr == 'Vehicle Duty') {
          themeColor = Colors.orange[800]!;
          leadingIcon = Icons.directions_bus;
        } else if (statusStr == 'Salary' || typeStr == 'Work') {
          themeColor = Colors.blue;
          leadingIcon = Icons.event_available;
        } else if (statusStr == 'Absent') {
          themeColor = Colors.red;
          leadingIcon = Icons.close;
        }

        final bool hasDescription = item['description'] != null && 
            item['description'].toString().trim().isNotEmpty && 
            item['description'] != '-' && 
            !item['description'].toString().contains('1st of Month') &&
            !item['description'].toString().startsWith('Attendance');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showWorkLogInfoDialog(context, item, data),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: themeColor.withValues(alpha: 0.12),
                            child: Icon(leadingIcon, color: themeColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] ?? (isPaid ? 'Payment Paid' : 'Attendance'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Date: ${item['date']}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (isPaid && modeStr != '-')
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                              ),
                              child: Text(modeStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                            ),
                          Text(
                            statusStr == 'Absent' ? '₹0' : '₹${rawAmt.toInt()}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusStr == 'Absent' ? Colors.grey : themeColor),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // DETAILED SUB-BOX (FOR VEHICLE DUTY DETAILS)
                  if (hasDescription) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 15, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['description'].toString(),
                              style: TextStyle(fontSize: 12, color: Colors.amber[900], fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWorkLogInfoDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    final typeStr = item['type']?.toString() ?? '';
    final statusStr = item['status']?.toString() ?? '';
    
    // Check if linked to a vehicle entry
    Map<String, dynamic>? matchingVehicle;
    if (item['id'] != null && item['id'].toString().startsWith('V-LOG-')) {
      final vId = item['id'].toString().replaceFirst('V-LOG-', '');
      try {
        matchingVehicle = data.vehicles.firstWhere(
          (v) => v['id'].toString() == vId,
        );
      } catch (_) {}
    }

    if (matchingVehicle != null && matchingVehicle.isNotEmpty) {
      final v = matchingVehicle;
      final rentAmt = data.parseAmount(v['rent_amount']);
      final battaAmt = data.parseAmount(v['batta'] ?? v['batta_amount']);
      final totalAmt = data.parseAmount(v['total']);
      final paidAmt = data.parseAmount(v['paid']);

      String custName = (v['customer'] ?? '').toString().trim();
      String siteName = (v['site'] ?? '').toString().trim();

      // Infer Customer Address if site name is empty or General
      if (siteName.isEmpty || siteName.toLowerCase() == 'general') {
        if (custName.isNotEmpty) {
          try {
            final custObj = data.customers.firstWhere(
              (c) => (c['name'] ?? '').toString().toLowerCase().trim() == custName.toLowerCase(),
              orElse: () => {},
            );
            if (custObj.isNotEmpty && custObj['address'] != null && custObj['address'].toString().trim().isNotEmpty) {
              siteName = custObj['address'].toString().trim();
            }
          } catch (_) {}
        }
      }
      if (siteName.isEmpty) siteName = 'General';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.directions_bus, color: JarvisTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${v['type'] ?? 'Vehicle'} Info',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Date:', v['date'] ?? 'N/A'),
                _buildInfoRow('Vehicle Number:', v['number'] ?? 'N/A'),
                if (v['bill_no']?.toString().isNotEmpty ?? false)
                  _buildInfoRow('Bill No:', v['bill_no'].toString()),
                if (custName.isNotEmpty)
                  _buildInfoRow('Customer:', custName),
                _buildInfoRow('Site / Address:', siteName),
                if (v['supplier']?.toString().isNotEmpty ?? false)
                  _buildInfoRow('Supplier:', v['supplier'].toString()),
                if (v['driver']?.toString().isNotEmpty ?? false)
                  _buildInfoRow('Driver:', v['driver'].toString()),
                const Divider(height: 16),
                if (v['duration']?.toString().isNotEmpty ?? false)
                  _buildInfoRow('Rental:', '${v['duration']} ${v['rate_type'] ?? 'Trip'} @ ₹${v['rate'] ?? '0'}'),
                if (rentAmt > 0)
                  _buildInfoRow('Hire/Rent:', '₹${rentAmt.toInt()}'),
                if (battaAmt > 0)
                  _buildInfoRow('Batta:', '₹${battaAmt.toInt()}'),
                if (v['material_name']?.toString().isNotEmpty ?? false)
                  _buildInfoRow('Material:', '${v['material_name']} (Qty: ${v['quantity'] ?? '0'})'),
                _buildInfoRow('Total Amount:', '₹${totalAmt.toInt()}', isBold: true, color: Colors.green[800]),
                if (paidAmt > 0)
                  _buildInfoRow('Paid:', '₹${paidAmt.toInt()}', color: Colors.blue),
                if (v['manual_desc']?.toString().isNotEmpty ?? false)
                  _buildInfoRow('Description:', v['manual_desc'].toString()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
            if (!AppConfig.isReadOnly)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JarvisTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddVehiclePaymentScreen(
                        isOwn: (v['isOwn'] == 1 || v['isOwn'] == true),
                        vehicle: v,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('EDIT ENTRY'),
              ),
          ],
        ),
      );
    } else {
      // General Info Dialog for Attendance or Salary Credit
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                typeStr == 'Attendance' ? Icons.badge : Icons.event_available,
                color: statusStr == 'Absent' ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                item['title'] ?? 'Entry Info',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Date:', item['date'] ?? 'N/A'),
              _buildInfoRow('Status:', statusStr.isNotEmpty ? statusStr : 'Recorded'),
              _buildInfoRow('Amount:', item['amount'] ?? '₹0', isBold: true, color: statusStr == 'Absent' ? Colors.red : Colors.green),
              if (item['description']?.toString().isNotEmpty ?? false)
                _buildInfoRow('Description:', item['description'].toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, {bool save = false, bool share = false}) async {
    try {
      final data = Provider.of<DataProvider>(context, listen: false);
      final targetId = widget.driverId.toString().trim().toLowerCase();
      final targetName = widget.driverName.toString().trim().toLowerCase();
      final driver = data.allDrivers.firstWhere(
        (d) {
          final dId = (d['id'] ?? '').toString().trim().toLowerCase();
          final dName = (d['name'] ?? '').toString().trim().toLowerCase();
          return dId == targetId || (targetName.isNotEmpty && dName == targetName);
        },
        orElse: () => {},
      );
      final ledger = await data.getDriverLedgerCategorized(widget.driverId);
      
      final paid = ledger['paid']!.where((item) => _isDateInRange(item['date'])).toList();
      final allWorkEntries = ledger['work']!.where((item) => _isDateInRange(item['date'])).toList();
      final combinedRows = _getFormattedLedgerRows(paid, allWorkEntries, data, driver);

      final List<List<String>> rows = [];
      Set<String> uniquePresentDates = {};
      Set<String> uniqueAbsentDates = {};
      double totalWork = 0;
      double totalPaidHistory = 0;

      for (var item in combinedRows) {
        final attStatus = item['attendance']?.toString() ?? '-';
        final rawAtt = item['rawAttStatus']?.toString() ?? '';
        final modeText = item['mode']?.toString() ?? '-';
        final paidAmt = (item['paid'] as num).toDouble();
        final earningsAmt = (item['earnings'] as num).toDouble();
        final isGiveAdvance = modeText == 'Give Advance' || modeText == 'Advance' || modeText.toLowerCase().contains('give advance') || modeText == 'Advance Box Given';
        final hasPayment = item['hasPayment'] as bool;
        final dateStr = item['date']?.toString() ?? '';

        if (attStatus.contains('Present') || rawAtt == 'Present') {
          uniquePresentDates.add(dateStr);
        } else if (attStatus.contains('Absent') || rawAtt == 'Absent') {
          if (!uniquePresentDates.contains(dateStr)) {
            uniqueAbsentDates.add(dateStr);
          }
        }

        totalWork += earningsAmt;
        if (!isGiveAdvance) {
          totalPaidHistory += paidAmt;
        }

        rows.add([
          dateStr, 
          attStatus, 
          modeText, 
          'Rs. ${earningsAmt.toInt()}',
          'Rs. ${paidAmt.toInt()}'
        ]);
      }

      // Advance Box Calculations
      final totalAdvanceDeducted = data.getDriverAdvanceDeducted(widget.driverId.toString());
      final initialAdv = data.getDriverInitialAdvance(driver);
      final remainingAdv = data.getDriverRemainingAdvance(driver);

      // Month-by-month summary grouping
      Map<String, Map<String, dynamic>> monthlyStats = {};
      for (var item in combinedRows) {
        final dStr = item['date']?.toString() ?? '';
        DateTime? d;
        try {
          d = DateFormat('dd MMM yyyy').parse(dStr);
        } catch (_) {}
        if (d == null) continue;

        final monthKey = DateFormat('MMM yyyy').format(d);
        if (!monthlyStats.containsKey(monthKey)) {
          monthlyStats[monthKey] = {
            'monthDate': DateTime(d.year, d.month, 1),
            'presentDates': <String>{},
            'absentDates': <String>{},
            'earnings': 0.0,
            'paid': 0.0,
            'advance': 0.0,
          };
        }

        final stats = monthlyStats[monthKey]!;
        final attStatus = item['attendance']?.toString() ?? '-';
        final rawAtt = item['rawAttStatus']?.toString() ?? '';
        final pMode = item['mode']?.toString() ?? '';
        final isGiveAdvance = pMode == 'Give Advance' || pMode == 'Advance' || pMode.toLowerCase().contains('give advance') || pMode == 'Advance Box Given';
        final paidAmt = (item['paid'] as num).toDouble();
        final earningsAmt = (item['earnings'] as num).toDouble();

        if (attStatus.contains('Present') || rawAtt == 'Present') {
          (stats['presentDates'] as Set<String>).add(dStr);
        } else if (attStatus.contains('Absent') || rawAtt == 'Absent') {
          if (!(stats['presentDates'] as Set<String>).contains(dStr)) {
            (stats['absentDates'] as Set<String>).add(dStr);
          }
        }

        stats['earnings'] = (stats['earnings'] as double) + earningsAmt;
        if (isGiveAdvance) {
          stats['advance'] = (stats['advance'] as double) + paidAmt;
        } else {
          stats['paid'] = (stats['paid'] as double) + paidAmt;
        }
      }

      List<MapEntry<String, Map<String, dynamic>>> sortedMonths = monthlyStats.entries.toList();
      sortedMonths.sort((a, b) => (a.value['monthDate'] as DateTime).compareTo(b.value['monthDate'] as DateTime));

      List<List<String>> monthlySummaryRows = [];
      for (var entry in sortedMonths) {
        final mName = entry.key;
        final stats = entry.value;
        final pCount = (stats['presentDates'] as Set<String>).length;
        final aCount = (stats['absentDates'] as Set<String>).length;
        final mEarnings = (stats['earnings'] as double);
        final mPaid = (stats['paid'] as double);
        final mAdv = (stats['advance'] as double);
        final mBal = mEarnings - mPaid;

        monthlySummaryRows.add([
          mName,
          '$pCount Days',
          '$aCount Days',
          'Rs. ${mEarnings.toInt()}',
          'Rs. ${mPaid.toInt()}',
          'Rs. ${mAdv.toInt()}',
          'Rs. ${mBal.toInt()}',
        ]);
      }

      final dbName = await data.getSetting('business_name');
      final businessName = (dbName != null && dbName.trim().isNotEmpty) ? dbName.trim() : 'Aandavar Solutions';
      final logoPath = await data.getLogoPath();

      final netBal = totalWork - totalPaidHistory;

      final totals = {
        'Total Present Days': '${uniquePresentDates.length} Days',
        'Total Absent Days': '${uniqueAbsentDates.length} Days',
        'Total Earnings': 'Rs. ${totalWork.toInt()}',
        'Total Paid': 'Rs. ${totalPaidHistory.toInt()}',
        'Net Balance': 'Rs. ${netBal.toInt()}',
        if (initialAdv > 0 || totalAdvanceDeducted > 0 || remainingAdv > 0) ...{
          'Advance Box Initial Total': 'Rs. ${initialAdv.toInt()}',
          'Advance Box Deducted (Used)': 'Rs. ${totalAdvanceDeducted.toInt()}',
          'Remaining Advance Box': 'Rs. ${remainingAdv.toInt()}',
        },
      };

      final pdfHeaders = ['Date', 'Attendance', 'Payment Mode', 'Salary', 'Amount Paid'];
      final alignments = {
        0: pw.Alignment.centerLeft, 
        1: pw.Alignment.centerLeft, 
        2: pw.Alignment.center, 
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      };

      final monthlySummaryData = monthlySummaryRows.isNotEmpty ? monthlySummaryRows : null;
      final monthlySummaryHeaders = ['Month', 'Present', 'Absent', 'Earnings', 'Paid', 'Advance Given', 'Balance'];

      if (share) {
        final file = await PdfService.getLedgerPdfFile(
          title: '${widget.driverName} - Driver Ledger',
          subTitle: _selectedDateRange != null ? 'Range: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}' : 'Complete History',
          headers: pdfHeaders,
          data: rows,
          totals: totals,
          businessName: businessName,
          logoPath: logoPath,
          cellAlignments: alignments,
          monthlySummaryData: monthlySummaryData,
          monthlySummaryHeaders: monthlySummaryHeaders,
        );

        String textSummary = "*$businessName*\n*DRIVER LEDGER: ${widget.driverName}*\n\n";
        for (var r in rows.take(20)) {
          textSummary += "${r[0]} | ${r[1]} | Salary: ${r[3]} | Paid: ${r[4]}\n";
        }
        totals.forEach((k, v) => textSummary += "$k: $v\n");

        await PdfService.showShareDialog(context, file, title: 'Share Driver Ledger PDF', textSummary: textSummary);
      } else if (save) {
        await PdfService.saveLedgerPdf(
          title: '${widget.driverName} - Driver Ledger',
          subTitle: _selectedDateRange != null ? 'Range: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}' : 'Complete History',
          headers: pdfHeaders,
          data: rows,
          totals: totals,
          businessName: businessName,
          logoPath: logoPath,
          cellAlignments: alignments,
          monthlySummaryData: monthlySummaryData,
          monthlySummaryHeaders: monthlySummaryHeaders,
        );
      } else {
        await PdfService.generateLedgerPdf(
          title: '${widget.driverName} - Driver Ledger',
          subTitle: _selectedDateRange != null ? 'Range: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}' : 'Complete History',
          headers: pdfHeaders,
          data: rows,
          totals: totals,
          businessName: businessName,
          logoPath: logoPath,
          cellAlignments: alignments,
          monthlySummaryData: monthlySummaryData,
          monthlySummaryHeaders: monthlySummaryHeaders,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save ? 'PDF Saved' : 'PDF Generated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateExcel(BuildContext context) async {
    try {
      final data = Provider.of<DataProvider>(context, listen: false);
      final driver = data.allDrivers.firstWhere((d) => d['id'].toString() == widget.driverId.toString(), orElse: () => {});
      final ledger = await data.getDriverLedgerCategorized(widget.driverId);
      
      final paid = ledger['paid']!.where((item) => _isDateInRange(item['date'])).toList();
      final allWorkEntries = ledger['work']!.where((item) => _isDateInRange(item['date'])).toList();
      final combinedRows = _getFormattedLedgerRows(paid, allWorkEntries, data, driver);

      final List<List<String>> rows = [];
      Set<String> uniquePresentDates = {};
      Set<String> uniqueAbsentDates = {};
      double totalWork = 0;
      double totalPaidHistory = 0;

      for (var item in combinedRows) {
        final attStatus = item['attendance']?.toString() ?? '-';
        final rawAtt = item['rawAttStatus']?.toString() ?? '';
        final modeText = item['mode']?.toString() ?? '-';
        final paidAmt = (item['paid'] as num).toDouble();
        final earningsAmt = (item['earnings'] as num).toDouble();
        final dateStr = item['date']?.toString() ?? '';

        if (attStatus.contains('Present') || rawAtt == 'Present') {
          uniquePresentDates.add(dateStr);
        } else if (attStatus.contains('Absent') || rawAtt == 'Absent') {
          if (!uniquePresentDates.contains(dateStr)) {
            uniqueAbsentDates.add(dateStr);
          }
        }

        totalWork += earningsAmt;
        totalPaidHistory += paidAmt;

        rows.add([
          dateStr, 
          attStatus, 
          modeText, 
          'Rs. ${earningsAmt.toInt()}',
          'Rs. ${paidAmt.toInt()}'
        ]);
      }

      final businessName = await data.getSetting('business_name');

      final totals = {
        'Total Present Days': '${uniquePresentDates.length} Days',
        'Total Absent Days': '${uniqueAbsentDates.length} Days',
        'Total Earnings': 'Rs. ${totalWork.toInt()}',
        'Total Paid': 'Rs. ${totalPaidHistory.toInt()}',
        'Net Balance': 'Rs. ${(totalWork - totalPaidHistory).toInt()}',
      };

      await ExcelService.generateLedgerExcel(
        title: '${widget.driverName} - Driver Ledger',
        subTitle: _selectedDateRange != null ? 'Range: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}' : 'Complete History',
        headers: ['Date', 'Attendance', 'Payment Mode', 'Salary', 'Amount Paid'],
        data: rows,
        totals: totals,
        businessName: businessName,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreditSalaryDialog(BuildContext context, Map<String, dynamic> driver) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final driverId = driver['id'].toString();
    final defaultSalary = provider.parseAmount(driver['salary'] ?? driver['earnings']);
    final salaryController = TextEditingController(text: defaultSalary > 0 ? defaultSalary.toInt().toString() : '');

    DateTime selectedMonth = DateTime.now();
    DateTime creditDate = DateTime.now();
    if (driver['date'] != null && driver['date'].toString().trim().isNotEmpty) {
      try {
        creditDate = DateFormat('dd MMM yyyy').parse(driver['date'].toString().trim());
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Credit Salary - ${driver['name'] ?? 'Driver'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select month and credit date for this driver:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    helpText: 'SELECT SALARY MONTH',
                  );
                  if (picked != null) {
                    setState(() {
                      selectedMonth = DateTime(picked.year, picked.month, 1);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month, color: JarvisTheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: creditDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    helpText: 'SELECT CREDIT DATE',
                  );
                  if (picked != null) {
                    setState(() {
                      creditDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Credit Date: ${DateFormat('dd MMM yyyy').format(creditDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today, color: JarvisTheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(
                  labelText: 'Salary Amount (₹)',
                  hintText: 'e.g. 15000',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: JarvisTheme.primary),
              onPressed: () async {
                final amt = provider.parseAmount(salaryController.text);
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid salary amount')),
                  );
                  return;
                }
                await provider.creditDriverMonthlySalary(driverId, selectedMonth, amt, creditDate: creditDate);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Credited ₹${amt.toInt()} salary for ${DateFormat('MMM yyyy').format(selectedMonth)} on ${DateFormat('dd MMM yyyy').format(creditDate)}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Credit Salary', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
