import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../providers/billing_provider.dart';
import '../models/invoice.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import 'package:path_provider/path_provider.dart';

class GstHistoryScreen extends StatefulWidget {
  const GstHistoryScreen({super.key});

  @override
  State<GstHistoryScreen> createState() => _GstHistoryScreenState();
}

class _GstHistoryScreenState extends State<GstHistoryScreen> {
  final PdfService _pdfService = PdfService();
  final ExcelService _excelService = ExcelService();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved GST Invoices'),
      ),
      body: FutureBuilder<List<Invoice>>(
        future: provider.loadSavedInvoices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                   SizedBox(height: 16),
                   Text('No saved invoices found', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          final invoices = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return Card(
                child: ListTile(
                  title: Text(invoice.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${invoice.customerName}\n${DateFormat('dd MMM yyyy').format(invoice.date)}'),
                  isThreeLine: true,
                  trailing: Text(
                    '₹${invoice.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                  ),
                  onTap: () => _showInvoiceActions(context, invoice, provider),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showInvoiceActions(BuildContext context, Invoice invoice, BillingProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('View PDF'),
            onTap: () async {
              Navigator.pop(context);
              final pdfBytes = await _pdfService.generateInvoice(invoice, provider.settings);
              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.blue),
            title: const Text('Share / Print'),
            onTap: () async {
              Navigator.pop(context);
              final pdfBytes = await _pdfService.generateInvoice(invoice, provider.settings);
              await Printing.sharePdf(bytes: pdfBytes, filename: 'invoice_${invoice.invoiceNo}.pdf');
            },
          ),
          ListTile(
            leading: const Icon(Icons.grid_on, color: Colors.green),
            title: const Text('Export to Excel'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final excelBytes = await _excelService.generateInvoice(invoice, provider.settings);
                if (excelBytes != null) {
                  final String docsPath;
                  if (Platform.isWindows) {
                    docsPath = (Platform.environment['USERPROFILE'] ?? '') + r'\Documents';
                  } else {
                    final dir = await getTemporaryDirectory();
                    docsPath = dir.path;
                  }
                  final folderPath = '$docsPath\\Jarvis Excels';
                  final folder = Directory(folderPath);
                  if (!folder.existsSync()) {
                    folder.createSync(recursive: true);
                  }
                  final filePath = '$folderPath\\invoice_${invoice.invoiceNo}.xlsx';
                  final file = File(filePath);
                  await file.writeAsBytes(excelBytes);
                  if (Platform.isWindows) {
                    await Process.run('cmd', ['/c', 'start', '', filePath]);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $filePath')));
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating Excel: $e')));
              }
            },
          ),
           ListTile(
            leading: const Icon(Icons.folder_open, color: Colors.orange),
            title: const Text('Open in Folder'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final dir = await provider.getInvoiceFolderPath();
                if (Platform.isWindows) {
                  await Process.run('explorer.exe', [dir]);
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved in: $dir')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open folder: $e')));
              }
            },
          ),
        ],
      ),
    );
  }
}
