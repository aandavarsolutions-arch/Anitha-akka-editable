import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import 'package:pdf/widgets.dart' as pw;

class SiteLedgerScreen extends StatefulWidget {
  final String siteName;

  const SiteLedgerScreen({super.key, required this.siteName});

  @override
  State<SiteLedgerScreen> createState() => _SiteLedgerScreenState();
}

class _SiteLedgerScreenState extends State<SiteLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  bool _isDateInRange(String? dateStr) {
    if (_selectedDateRange == null) return true;
    if (dateStr == null) return true;
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
             date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    } catch (_) { return false; }
  }

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
        title: Text('${widget.siteName} LEDGER'),

        actions: [
            if (_selectedDateRange != null)
              IconButton(
                icon: const Icon(Icons.highlight_off),
                tooltip: 'Clear Date Filter',
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
                 if (picked != null) {
                    setState(() => _selectedDateRange = picked);
                 }
              },
              tooltip: 'Filter by Date',
            ),
             IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _generatePdf(context, Provider.of<DataProvider>(context, listen: false), save: true),
                tooltip: 'Save as PDF',
            ),
             IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => _generatePdf(context, Provider.of<DataProvider>(context, listen: false)),
                tooltip: 'Print',
            ),
             IconButton(
                icon: const Icon(Icons.grid_on),
                onPressed: () => _generateExcel(context, Provider.of<DataProvider>(context, listen: false)),
                tooltip: 'Export as Excel',
            ),
            const DevBrandingBadge()
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: JarvisTheme.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'UNPAID'),
            Tab(text: 'PAID'),
          ],
        ),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: data.getSiteLedgerCategorized(widget.siteName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('No data found'));
              }

              final paid = snapshot.data!['paid']!.where((item) => _isDateInRange(item['date'])).toList();
              final unpaid = snapshot.data!['unpaid']!.where((item) => _isDateInRange(item['date'])).toList();

              return Column(
                children: [
                   Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLedgerList(unpaid, false, data), // Unpaid First
                        _buildLedgerList(paid, true, data),
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

  Widget _buildLedgerList(List<Map<String, dynamic>> items, bool isPaidTab, DataProvider data) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedDateRange == null ? Icons.date_range : (isPaidTab ? Icons.check_circle_outline : Icons.pending_actions),
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedDateRange == null 
                  ? 'Select a Date Range to view records' 
                  : (isPaidTab ? 'No paid transactions in this range' : 'No pending amounts in this range'),
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isIncome = item['type'] == 'Income';
        final bool isSupplierPaid = item['isSupplierPaid'] ?? false;
        
        String desc = item['description'];
        if (item['material_name'] != null && item['material_name'].toString().isNotEmpty) {
           desc += ' (${item['material_name']}';
           if (item['quantity'] != null && item['quantity'].toString().isNotEmpty) {
              desc += ' - ${item['quantity']} ${item['unit'] ?? ''}';
           }
           desc += ')';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    child: Icon(
                      isIncome ? Icons.add : Icons.remove,
                      color: isIncome ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          desc,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (isPaidTab) ...[
                          Text('Paid: ${item['date']}'),
                          Text(
                            'Bill: ${item['billDate']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ] else ...[
                          Text('Bill Date: ${item['date']}'),
                        ]
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                       Text(
                        item['amount'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                      if (!isPaidTab)
                       Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isSupplierPaid ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSupplierPaid ? 'PAID' : 'PENDING',
                          style: TextStyle(color: isSupplierPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                       ),
                    ],
                  ),
                ],
              ),
          ),
        );
      },
    );
  }

  Future<void> _generatePdf(BuildContext context, DataProvider data, {bool save = false}) async {
    try {
        final ledgerData = await data.getSiteLedgerCategorized(widget.siteName);
        
        // Merge both lists to process all transactions in date range
        final allItems = [
           ...ledgerData['unpaid']!, 
           ...ledgerData['paid']!
        ].where((item) => _isDateInRange(item['date'])).toList();

        // Separate Income and Expense
        final incomeItems = allItems.where((i) => i['type'] == 'Income').toList();
        final expenseItems = allItems.where((i) => i['type'] != 'Income').toList();

        final List<List<String>> rows = [];
        double totalIncome = 0;
        double totalExpense = 0;

        // 1. EXPENSES
        if (expenseItems.isNotEmpty) {
           rows.add(['--- EXPENSES ---', '', '', '']);
           for (var item in expenseItems) {
               String desc = item['description'] ?? 'Expense';
               String material = '';
               
               if (item['material_name'] != null && item['material_name'].toString().isNotEmpty) {
                  material = item['material_name'];
                  if (item['quantity'] != null && item['quantity'].toString().isNotEmpty) {
                     material += ' - ${item['quantity']} ${item['unit'] ?? ''}';
                  }
               }
               
               double amt = data.parseAmount(item['amount']);
               totalExpense += amt;

               rows.add([
                   item['billDate'] ?? item['date'] ?? '',
                   desc,
                   material,
                   'Rs. ${amt.toInt()}'
               ]);
           }
           rows.add(['', '', '', '']); // Spacer
        }

        // 2. INCOME
        if (incomeItems.isNotEmpty) {
           rows.add(['--- INCOME ---', '', '', '']);
           for (var item in incomeItems) {
               double amt = data.parseAmount(item['amount']);
               totalIncome += amt;
               
               rows.add([
                   item['billDate'] ?? item['date'] ?? '',
                   item['description'] ?? 'Income',
                   '',
                   'Rs. ${amt.toInt()}'
               ]);
           }
        }
        
        double netIncome = totalIncome - totalExpense;
        
        Map<String, String> totals = {
            'Total Expenses': 'Rs. ${totalExpense.toInt()}',
            'Total Income': 'Rs. ${totalIncome.toInt()}',
            'Net Income': 'Rs. ${netIncome.toInt()}'
        };
        
        final businessName = await data.getSetting('business_name');
        final logoPath = await data.getLogoPath();

        if (save) {
           await PdfService.saveLedgerPdf(
              title: '${widget.siteName} Ledger',
              subTitle: _selectedDateRange != null 
                  ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}'
                  : 'Site Profit & Loss Statement',
              headers: ['Date', 'Description', 'Material', 'Amount'],
              data: rows,
              totals: totals,
              businessName: businessName,
              logoPath: logoPath,
              cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
              }
           );
        } else {
           await PdfService.generateLedgerPdf(
              title: '${widget.siteName} Ledger',
              subTitle: _selectedDateRange != null 
                  ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}'
                  : 'Site Profit & Loss Statement',
              headers: ['Date', 'Description', 'Material', 'Amount'],
              data: rows,
              totals: totals,
              businessName: businessName,
              logoPath: logoPath,
              cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
              }
           );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save ? 'PDF Saved' : 'Report Generated Successfully')));

    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateExcel(BuildContext context, DataProvider data) async {
     try {
         final ledgerData = await data.getSiteLedgerCategorized(widget.siteName);
         final filteredTrips = ledgerData['trips']!.where((item) => _isDateInRange(item['date'])).toList();
         final filteredExpenses = ledgerData['expenses']!.where((item) => _isDateInRange(item['date'])).toList();

         filteredTrips.sort((a, b) {
            try {
               DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
               DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
               return da.compareTo(db);
            } catch(_) { return 0; }
         });
         filteredExpenses.sort((a, b) {
            try {
               DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
               DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
               return da.compareTo(db);
            } catch(_) { return 0; }
         });

         final List<List<String>> rows = [];
         double totalIncome = 0;
         if (filteredTrips.isNotEmpty) {
           rows.add(['--- INCOME (TRIPS) ---', '', '', '']);
           for (var item in filteredTrips) {
              double amt = data.parseAmount(item['total']);
              totalIncome += amt;
              String matName = item['material_name'] ?? '-';
              if (item['quantity'] != null && item['quantity'].toString().isNotEmpty && item['quantity'].toString() != '0') {
                 matName += ' (${item['quantity']} ${item['unit'] ?? ''})';
              }
              rows.add([
                 item['date'] ?? '',
                 'Trip: ${item['vehicle_no'] ?? ''}',
                 matName,
                 '+Rs. ${amt.toInt()}'
              ]);
           }
           rows.add(['', '', '', '']);
         }

         double totalExpense = 0;
         if (filteredExpenses.isNotEmpty) {
           rows.add(['--- EXPENSES ---', '', '', '']);
           for (var item in filteredExpenses) {
              double amt = data.parseAmount(item['amount']);
              totalExpense += amt;
              rows.add([
                 item['date'] ?? '',
                 item['description'] ?? 'Expense',
                 '-',
                 '-Rs. ${amt.toInt()}'
              ]);
           }
         }

         final Map<String, String> totals = {
            'Total Income': 'Rs. ${totalIncome.toInt()}',
            'Total Expense': 'Rs. ${totalExpense.toInt()}',
            'Net Profit': 'Rs. ${(totalIncome - totalExpense).toInt()}',
         };

         final businessName = await data.getSetting('business_name');

         await ExcelService.generateLedgerExcel(
            title: '${widget.siteName} Ledger',
            subTitle: _selectedDateRange != null 
                ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}'
                : 'Site Profit & Loss Statement',
            headers: ['Date', 'Description', 'Material', 'Amount'],
            data: rows,
            totals: totals,
            businessName: businessName,
         );
         
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated Successfully')));

     } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }
}
