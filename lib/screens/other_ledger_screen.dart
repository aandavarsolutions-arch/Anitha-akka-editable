import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../app_config.dart';

class OtherLedgerScreen extends StatefulWidget {
  final String title;

  const OtherLedgerScreen({super.key, required this.title});

  @override
  State<OtherLedgerScreen> createState() => _OtherLedgerScreenState();
}

class _OtherLedgerScreenState extends State<OtherLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

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

  bool _isDateInRange(String? dateStr) {
    if (_selectedDateRange == null) return true;
    if (dateStr == null) return false;
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
             date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    
    double totalBalance = 0;
    final expenses = data.allSiteExpenses.where((e) => 
        e['category'] == 'Other' && 
        e['title']?.toString().toLowerCase().trim() == widget.title.toLowerCase().trim()
    );
    for (var e in expenses) {
       totalBalance += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
    }

    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: Text(widget.title.toUpperCase()),
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
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _generatePdf(data, save: true),
                tooltip: 'Save as PDF',
             ),
             IconButton(
                icon: const Icon(Icons.grid_on),
                onPressed: () => _generateExcel(data),
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
            Tab(text: 'PENDING'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      bottomNavigationBar: Container(
         padding: const EdgeInsets.all(16),
         decoration: const BoxDecoration(
           color: Colors.white,
           boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,-5))],
         ),
         child: SafeArea(
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('₹${totalBalance.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                if (!AppConfig.isReadOnly)
                  ElevatedButton.icon(
                    onPressed: () => _showBulkPayDialog(context),
                    icon: const Icon(Icons.payment),
                    label: const Text('PAY ALL'),
                    style: ElevatedButton.styleFrom(backgroundColor: JarvisTheme.primary, foregroundColor: Colors.white),
                  ),
             ],
           ),
         ),
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: data.getOtherLedgerCategorized(widget.title),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
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
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isUnpaid}) {
    if (items.isEmpty) return Center(child: Text(isUnpaid ? 'No pending entries' : 'No history found', style: const TextStyle(color: Colors.grey)));

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
              child: Icon(isPayment ? Icons.check : Icons.receipt, color: isPayment ? Colors.green : Colors.blue, size: 20),
            ),
            title: Text(item['title'] ?? (isPayment ? 'Payment' : 'Salary Entry'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['description'] ?? ''),
                if (item['date'] != null) Text(item['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Text(
              item['amount'] ?? '',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPayment ? Colors.green : Colors.red),
            ),
          ),
        );
      },
    );
  }

  void _showBulkPayDialog(BuildContext context) {
     final data = Provider.of<DataProvider>(context, listen: false);
     final unpaidExpenses = data.allSiteExpenses.where((e) => 
        e['category'] == 'Other' && 
        e['title']?.toString().toLowerCase().trim() == widget.title.toLowerCase().trim() &&
        (data.parseAmount(e['amount']) - data.parseAmount(e['paid'])) > 0
     ).toList();

     if (unpaidExpenses.isEmpty) { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All bills items are already paid!')));
        return; 
     }

     double totalOwed = 0;
     for (var e in unpaidExpenses) {
       totalOwed += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
     }

     final controller = TextEditingController(text: totalOwed.toInt().toString());
     DateTime selectedDate = DateTime.now();

     showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
         builder: (context, setSt) => AlertDialog(
           title: Text('Pay for ${widget.title}'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text('Pending Amount: ₹${totalOwed.toInt()}'),
               const SizedBox(height: 16),
               TextField(
                 controller: controller,
                 decoration: const InputDecoration(labelText: 'Amount Paid (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 16),
               ListTile(
                  title: Text('Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                     final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                     if (p != null) setSt(() => selectedDate = p);
                  },
               )
             ],
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
             ElevatedButton(
               onPressed: () async {
                  final pay = double.tryParse(controller.text) ?? 0;
                  if (pay <= 0) return;
                  Navigator.pop(context);
                  
                  double remaining = pay;
                  for (var e in unpaidExpenses) {
                     if (remaining <= 0) break;
                     double bal = data.parseAmount(e['amount']) - data.parseAmount(e['paid']);
                     double toPay = remaining >= bal ? bal : remaining;
                     
                     await data.addExpensePayment(e['id'], {
                        'amount': '₹${toPay.toInt()}',
                        'date': DateFormat('dd MMM yyyy').format(selectedDate),
                     });
                     remaining -= toPay;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payments recorded successfully')));
               },
               child: const Text('CONFIRM'),
             ),
           ],
         ),
       ),
     );
  }

  Future<void> _generatePdf(DataProvider data, {required bool save}) async {
     try {
        final ledger = await data.getOtherLedgerCategorized(widget.title);
        final unpaid = ledger['unpaid']!.where((item) => _isDateInRange(item['date'])).toList();
        final paid = ledger['paid']!.where((item) => _isDateInRange(item['date'])).toList();

        final List<List<String>> rows = [];
        if (unpaid.isNotEmpty) {
           rows.add(['--- PENDING BILLS ---', '', '', '', '']);
           for (var i in unpaid) {
              String desc = widget.title;
              if (i['desc_text'] != null && i['desc_text'].toString().isNotEmpty && i['desc_text'] != widget.title) {
                 desc += ' - ${i['desc_text']}';
              }
              rows.add([i['date']??'', i['site']??'', desc, i['amount'], 'PENDING']);
           }
        }
        if (paid.isNotEmpty) {
           if (rows.isNotEmpty) rows.add(['', '', '', '', '']);
           rows.add(['--- HISTORY ---', '', '', '', '']);
           for (var i in paid) {
              String desc = widget.title;
              if (i['title'] == 'Payment Made') {
                 desc = 'PAYMENT';
              } else {
                 if (i['desc_text'] != null && i['desc_text'].toString().isNotEmpty && i['desc_text'] != widget.title) {
                    desc += ' - ${i['desc_text']}';
                 }
              }
              rows.add([i['date']??'', i['site']??'', desc, i['amount'], i['type'] == 'Payment' ? 'PAID' : 'BILLED']);
           }
        }

        // Calculate Outstanding
        double totalBalance = 0;
        final expenses = data.allSiteExpenses.where((e) => 
            e['category'] == 'Other' && 
            e['title']?.toString().toLowerCase().trim() == widget.title.toLowerCase().trim()
        );
        for (var e in expenses) {
           totalBalance += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
        }
        final Map<String, String> totals = { 'Outstanding': '₹${totalBalance.toInt()}' };
        
        if (save) {
           await PdfService.saveLedgerPdf(
             title: '${widget.title} Ledger',
             subTitle: 'Statement of Account',
             headers: ['Date', 'Site', 'Description', 'Amount', 'Status'],
             data: rows,
             totals: totals,
             businessName: await data.getSetting('business_name'),
             logoPath: await data.getLogoPath(),
           );
        } else {
           await PdfService.generateLedgerPdf(
             title: '${widget.title} Ledger',
             subTitle: 'Statement of Account',
             headers: ['Date', 'Site', 'Description', 'Amount', 'Status'],
             data: rows,
             totals: totals,
             businessName: await data.getSetting('business_name'),
             logoPath: await data.getLogoPath(),
           );
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ledger PDF Generated')));
     } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e')));
     }
  }

  Future<void> _generateExcel(DataProvider data) async {
     try {
        final ledger = await data.getOtherLedgerCategorized(widget.title);
        final filteredBills = ledger['all_bills']!.where((item) => _isDateInRange(item['date'])).toList();
        final filteredPayments = ledger['paid']!.where((item) => _isDateInRange(item['date'])).toList();

        filteredBills.sort((a, b) {
           try {
              return DateFormat('dd MMM yyyy').parse(a['date']).compareTo(DateFormat('dd MMM yyyy').parse(b['date']));
           } catch(_) { return 0; }
        });
        filteredPayments.sort((a, b) {
           try {
              return DateFormat('dd MMM yyyy').parse(a['date']).compareTo(DateFormat('dd MMM yyyy').parse(b['date']));
           } catch(_) { return 0; }
        });

        final List<List<String>> rows = [];
        double totalBilled = 0;
        if (filteredBills.isNotEmpty) {
          rows.add(['--- BILLS ---', '', '', '', '']);
          for (var item in filteredBills) {
             double amt = data.parseAmount(item['amount']);
             totalBilled += amt;
             rows.add([
                item['date'] ?? '',
                item['site'] ?? 'General',
                item['description'] ?? '',
                'Rs. ${amt.toInt()}',
                'Unpaid'
             ]);
          }
          rows.add(['', '', '', '', '']);
        }

        double totalPaid = 0;
        if (filteredPayments.isNotEmpty) {
          rows.add(['--- PAYMENTS ---', '', '', '', '']);
          for (var item in filteredPayments) {
             double amt = data.parseAmount(item['amount']);
             totalPaid += amt;
             rows.add([
                item['date'] ?? '',
                '-',
                item['description'] ?? 'Payment',
                'Rs. ${amt.toInt()}',
                'Paid'
             ]);
          }
        }

        double totalBalance = 0;
        final expenses = data.allSiteExpenses.where((e) => 
            e['category'] == 'Other' && 
            e['title']?.toString().toLowerCase().trim() == widget.title.toLowerCase().trim()
        );
        for (var e in expenses) {
           totalBalance += (data.parseAmount(e['amount']) - data.parseAmount(e['paid']));
        }

        final Map<String, String> totals = {
           'Total Outstanding': 'Rs. ${totalBalance.toInt()}',
           'Total Billed': 'Rs. ${totalBilled.toInt()}',
           'Total Paid': 'Rs. ${totalPaid.toInt()}',
        };

        final businessName = await data.getSetting('business_name');

        await ExcelService.generateLedgerExcel(
           title: '${widget.title} Ledger',
           subTitle: 'Statement of Account',
           headers: ['Date', 'Site', 'Description', 'Amount', 'Status'],
           data: rows,
           totals: totals,
           businessName: businessName,
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated')));
     } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel Error: $e')));
     }
  }
}
