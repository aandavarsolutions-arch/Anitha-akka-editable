
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../app_config.dart';

class LabourLedgerScreen extends StatefulWidget {
  final String workerName;

  const LabourLedgerScreen({super.key, required this.workerName});

  @override
  State<LabourLedgerScreen> createState() => _LabourLedgerScreenState();
}

class _LabourLedgerScreenState extends State<LabourLedgerScreen> with SingleTickerProviderStateMixin {
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
    return Consumer<DataProvider>(
      builder: (context, data, child) {
        // Calculate Live Total Balance from all entries for this name in _labour
        // Calculate Live Total Balance from all entries for this name in _labour and _siteExpenses
        final workerEntries = data.allLabour.where((l) => l['name']?.toString().toLowerCase().trim() == widget.workerName.toLowerCase().trim());
        final expenseEntries = data.allSiteExpenses.where((e) => e['category'] == 'Labour' && e['title']?.toString().toLowerCase().trim() == widget.workerName.toLowerCase().trim());

        double totalBalance = 0;
        for (var l in workerEntries) {
           totalBalance += data.parseAmount(l['balance']);
        }
        for (var e in expenseEntries) {
           totalBalance += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
        }

        return Scaffold(
          backgroundColor: JarvisTheme.background,
          appBar: AppBar(
            title: Text('${widget.workerName.toUpperCase()} - LEDGER'),
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
                  onPressed: () => _showPdfOptions(context, data),
                  tooltip: 'PDF Options',
                ),
                const DevBrandingBadge()
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: JarvisTheme.secondary,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'PENDING'),
                Tab(text: 'HISTORY'),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL BALANCE DUE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text('₹${totalBalance.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  if (!AppConfig.isReadOnly)
                    ElevatedButton.icon(
                      onPressed: () => _showBulkPayDialog(context),
                      icon: const Icon(Icons.payment),
                      label: const Text('PAY ALL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JarvisTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: data.getLabourLedgerCategorized(widget.workerName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) return const Center(child: Text('No data found'));

              final unpaid = snapshot.data!['unpaid']!.where((item) => _isDateInRange(item['date'])).toList();
              final paid = snapshot.data!['paid']!.where((item) => _isDateInRange(item['date'])).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildList(unpaid, isUnpaid: true),
                  _buildList(paid, isUnpaid: false),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isUnpaid}) {
    if (items.isEmpty) {
      return Center(child: Text(isUnpaid ? 'No pending entries' : 'No history found', style: const TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isPayment = item['type'] == 'Payment';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPayment ? Colors.green.shade50 : Colors.blue.shade50,
              child: Icon(
                isPayment ? Icons.check : Icons.receipt,
                color: isPayment ? Colors.green : Colors.blue,
                size: 20,
              ),
            ),
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['description']),
                if (item['date'] != null) Text(item['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                  Text(
                    item['amount'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16, 
                      color: isPayment ? Colors.green : Colors.red
                    ),
                  ),
                  if (!isPayment && item['balance'] != null && item['balance'] != item['amount'])
                    Text('Bal: ${item['balance']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
               ],
            ),
          ),
        );
      },
    );
  }

  void _showBulkPayDialog(BuildContext context) {
     final data = Provider.of<DataProvider>(context, listen: false);
     
     // Collect pending from Labour Table
     final labourEntries = data.allLabour.where((l) => l['name']?.toString().toLowerCase().trim() == widget.workerName.toLowerCase().trim() && data.parseAmount(l['balance']) > 0).toList();
     // Collect pending from Expenses Table
     final expenseEntries = data.allSiteExpenses.where((e) => 
        e['category'] == 'Labour' && 
        e['title']?.toString().toLowerCase().trim() == widget.workerName.toLowerCase().trim() &&
        (data.parseAmount(e['amount']) - data.parseAmount(e['paid'])) > 0
     ).toList();

     if (labourEntries.isEmpty && expenseEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending balances to pay.')));
        return;
     }

     double totalOwed = 0;
     for (var l in labourEntries) {
       totalOwed += data.parseAmount(l['balance']);
     }
     for (var e in expenseEntries) {
       totalOwed += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
     }

     final controller = TextEditingController(text: totalOwed.toInt().toString());
     DateTime selectedDate = DateTime.now();

     showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
         builder: (context, setSt) => AlertDialog(
           title: Text('Pay ${widget.workerName}'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text('Total Pending: ₹${totalOwed.toInt()}'),
               const SizedBox(height: 16),
               TextField(
                 controller: controller,
                 decoration: const InputDecoration(labelText: 'Amount to Pay (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 16),
               ListTile(
                 title: Text('Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                 trailing: const Icon(Icons.calendar_today),
                 onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setSt(() => selectedDate = picked);
                 },
               ),
             ],
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
             ElevatedButton(
               onPressed: () async {
                  final amount = double.tryParse(controller.text) ?? 0;
                  if (amount <= 0) return;

                  Navigator.pop(context);
                  double remaining = amount;
                  
                  // Pay Labour Table Entries
                  for (var l in labourEntries) {
                     if (remaining <= 0) break;
                     double bal = data.parseAmount(l['balance']);
                     double pay = remaining >= bal ? bal : remaining;
                     
                     await data.addLabourPayment(l['id'], pay, DateFormat('dd MMM yyyy').format(selectedDate));
                     remaining -= pay;
                  }

                  // Pay Expense Entries
                  for (var e in expenseEntries) {
                     if (remaining <= 0) break;
                     double bal = data.parseAmount(e['amount']) - data.parseAmount(e['paid']);
                     double pay = remaining >= bal ? bal : remaining;
                     
                     await data.addExpensePayment(e['id'], {
                        'amount': '₹${pay.toInt()}',
                        'date': DateFormat('dd MMM yyyy').format(selectedDate),
                     });
                     remaining -= pay;
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded and applied.')));
               },
               child: const Text('CONFIRM'),
             ),
           ],
         ),
       ),
     );
  }

  void _showPdfOptions(BuildContext context, DataProvider data) {
     showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Save as PDF'),
                onTap: () { Navigator.pop(ctx); _generatePdf(data, save: true); },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Colors.blue),
                title: const Text('Print Ledger'),
                onTap: () { Navigator.pop(ctx); _generatePdf(data, save: false); },
              ),
              ListTile(
                leading: const Icon(Icons.grid_on, color: Colors.green),
                title: const Text('Export to Excel'),
                onTap: () { Navigator.pop(ctx); _generateExcel(data); },
              ),
            ],
          ),
        ),
     );
  }

  Future<void> _generatePdf(DataProvider data, {required bool save}) async {
     try {
        final ledger = await data.getLabourLedgerCategorized(widget.workerName);
        final unpaid = ledger['unpaid']!.where((item) => _isDateInRange(item['date'])).toList();
        final paid = ledger['paid']!.where((item) => _isDateInRange(item['date'])).toList();

        final List<List<String>> rows = [];
        
        // Header for Unpaid
        if (unpaid.isNotEmpty) {
           rows.add(['--- PENDING ENTRIES ---', '', '', '']);
           for (var item in unpaid) {
              rows.add([
                item['date'] ?? '',
                item['description'] ?? '',
                item['amount'] ?? '',
                'PENDING',
              ]);
           }
        }
        
        // Header for Paid/History
        if (paid.isNotEmpty) {
           if (rows.isNotEmpty) rows.add(['', '', '', '']);
           rows.add(['--- TRANSACTION HISTORY ---', '', '', '']);
           for (var item in paid) {
              rows.add([
                item['date'] ?? '',
                item['title'] == 'Payment Paid' ? 'PAYMENT OUT' : (item['description'] ?? ''),
                item['amount'] ?? '',
                item['title'] == 'Payment Paid' ? 'PAID' : 'BILLED',
              ]);
           }
        }

        final workerEntries = data.allLabour.where((l) => l['name']?.toString().toLowerCase().trim() == widget.workerName.toLowerCase().trim());
        final expenseEntries = data.allSiteExpenses.where((e) => e['category'] == 'Labour' && e['title']?.toString().toLowerCase().trim() == widget.workerName.toLowerCase().trim());
        double totalBalance = 0;
        for (var l in workerEntries) {
          totalBalance += data.parseAmount(l['balance']);
        }
        for (var e in expenseEntries) {
          totalBalance += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
        }

        final Map<String, String> totals = {
           'Total Outstanding': 'Rs. ${totalBalance.toInt()}',
        };

        if (save) {
           await PdfService.saveLedgerPdf(
             title: '${widget.workerName} - Labour Ledger',
             subTitle: _selectedDateRange != null ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}' : 'Account Statement',
             headers: ['Date', 'Description', 'Amount', 'Status'],
             data: rows,
             totals: totals,
             businessName: await data.getSetting('business_name'),
             logoPath: await data.getLogoPath(),
           );
        } else {
           await PdfService.generateLedgerPdf(
             title: '${widget.workerName} - Labour Ledger',
             subTitle: _selectedDateRange != null ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}' : 'Account Statement',
             headers: ['Date', 'Description', 'Amount', 'Status'],
             data: rows,
             totals: totals,
             businessName: await data.getSetting('business_name'),
             logoPath: await data.getLogoPath(),
           );
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save ? 'PDF Saved' : 'Printing...')));
     } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
     }
  }

  Future<void> _generateExcel(DataProvider data) async {
     try {
        final ledger = await data.getLabourLedgerCategorized(widget.workerName);
        final unpaid = ledger['unpaid']!.where((item) => _isDateInRange(item['date'])).toList();
        final paid = ledger['paid']!.where((item) => _isDateInRange(item['date'])).toList();

        unpaid.sort((a, b) {
           try {
              return DateFormat('dd MMM yyyy').parse(a['date']).compareTo(DateFormat('dd MMM yyyy').parse(b['date']));
           } catch(_) { return 0; }
        });
        paid.sort((a, b) {
           try {
              return DateFormat('dd MMM yyyy').parse(a['date']).compareTo(DateFormat('dd MMM yyyy').parse(b['date']));
           } catch(_) { return 0; }
        });

        final List<List<String>> rows = [];
        double totalUnpaid = 0;
        if (unpaid.isNotEmpty) {
          rows.add(['--- UNPAID WORK ---', '', '', '']);
          for (var item in unpaid) {
             double amt = data.parseAmount(item['amount']);
             totalUnpaid += amt;
             rows.add([
                item['date'] ?? '',
                item['description'] ?? 'Work',
                'Rs. ${amt.toInt()}',
                'Unpaid'
             ]);
          }
          rows.add(['', '', '', '']);
        }

        double totalPaid = 0;
        if (paid.isNotEmpty) {
          rows.add(['--- PAYMENTS ---', '', '', '']);
          for (var item in paid) {
             double amt = data.parseAmount(item['amount']);
             totalPaid += amt;
             rows.add([
                item['date'] ?? '',
                item['description'] ?? 'Payment',
                'Rs. ${amt.toInt()}',
                'Paid'
             ]);
          }
        }

        final totals = {
           'Total Earned': 'Rs. ${totalUnpaid.toInt()}',
           'Total Paid': 'Rs. ${totalPaid.toInt()}',
           'Balance Due': 'Rs. ${(totalUnpaid - totalPaid).toInt()}',
        };

        final businessName = await data.getSetting('business_name');

        await ExcelService.generateLedgerExcel(
           title: '${widget.workerName} - Labour Ledger',
           subTitle: _selectedDateRange != null ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}' : 'Account Statement',
           headers: ['Date', 'Description', 'Amount', 'Status'],
           data: rows,
           totals: totals,
           businessName: businessName,
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated')));
     } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating Excel: $e')));
     }
  }
}
