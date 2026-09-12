import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shop_settings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
class PdfService {
  static final PdfColor _tealHeaderColor = PdfColor.fromHex('#156D84');
  static final PdfColor _darkGreenHeaderColor = PdfColor.fromHex('#1B7537');

  static Future<Uint8List?> _getHeaderImageBytes([String? customPath]) async {
    final hPath = customPath ?? 'assets/customer_header.png';
    if (File(hPath).existsSync()) {
      return File(hPath).readAsBytesSync();
    }
    try {
      final ByteData data = await rootBundle.load(hPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _getLogoImageBytes([String? logoPath]) async {
    if (logoPath != null && File(logoPath).existsSync()) {
      return File(logoPath).readAsBytesSync();
    }
    try {
      final ByteData data = await rootBundle.load('assets/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeaderBanner({
    Uint8List? headerImageBytes,
    Uint8List? logoBytes,
    String? shopNameTamil,
    String? shopSubTitleTamil,
    String? shopAddressTamil,
    String? contactPhone,
    required double width,
  }) {
    if (headerImageBytes != null) {
      return pw.Image(
        pw.MemoryImage(headerImageBytes),
        width: width,
        height: (width / 595.28) * 105,
        fit: pw.BoxFit.fill,
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20),
      child: pw.Column(
        children: [
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('பாட்டன் துணை', style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text('உ', style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('அருள்மிகு பெரியநாயகி அம்மன் துணை', style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Container(
                  height: 55,
                  width: 55,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(width: 55),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      shopNameTamil ?? 'அருள்மிகு பெரியநாயகி அம்மன்',
                      style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 17),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      shopSubTitleTamil ?? 'எர்த் மூவர்ஸ்',
                      style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 20),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      shopAddressTamil ?? 'விஸ்கோஸ், சண்முகாநகர்.',
                      style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      contactPhone ?? 'செல் : 99423 97979, 99422 02618',
                      style: pw.TextStyle(color: _darkGreenHeaderColor, fontWeight: pw.FontWeight.bold, fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (logoBytes != null)
                pw.Container(
                  height: 55,
                  width: 55,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(width: 55),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 4,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _darkGreenHeaderColor, width: 1.5),
                bottom: pw.BorderSide(color: _darkGreenHeaderColor, width: 1.5),
              ),
            ),
          ),
          pw.SizedBox(height: 6),
        ],
      ),
    );
  }

  static pw.Widget _buildDocTitleBanner(String docTitle, {double marginHorizontal = 20}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: marginHorizontal),
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: _tealHeaderColor,
          border: pw.Border.all(color: PdfColors.black, width: 0.8),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Center(
          child: pw.Text(
            docTitle.toUpperCase(),
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11.5),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> generateInvoice(Invoice invoice, ShopSettings settings) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    
    // Calculate split tax
    final cgstPercent = invoice.gstPercentage / 2;
    final sgstPercent = invoice.gstPercentage / 2;
    final cgstAmount = invoice.gstAmount / 2;
    final sgstAmount = invoice.gstAmount / 2;
    
    // Number to text helper (Indian Format)
    String getNumberWords(double amount) {
      if (amount == 0) return "Zero";
      
      final units = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"];
      final tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];
      String convert(int n) {
        if (n < 20) return units[n];
        if (n < 100) return "${tens[n ~/ 10]} ${units[n % 10]}";
        if (n < 1000) return "${units[n ~/ 100]} Hundred ${convert(n % 100)}";
        if (n < 100000) return "${convert(n ~/ 1000)} Thousand ${convert(n % 1000)}";
        if (n < 10000000) return "${convert(n ~/ 100000)} Lakh ${convert(n % 100000)}";
        return "${convert(n ~/ 10000000)} Crore ${convert(n % 10000000)}";
      }
      int intAmount = amount.round();
      return "${convert(intAmount)} Only"; 
    }
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Header Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GSTIN : ${settings.sellerGst}', style: pw.TextStyle(color: PdfColors.blue, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          if (settings.contactNumbers.isNotEmpty)
                             pw.Text('CELL : ${settings.contactNumbers}', style: pw.TextStyle(color: PdfColors.blue, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        ]),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Center(child: pw.Text(settings.shopName, style: pw.TextStyle(color: PdfColors.blue, fontWeight: pw.FontWeight.bold, fontSize: 22))),
                    pw.SizedBox(height: 4),
                    if (settings.shopAddress.isNotEmpty)
                      pw.Center(child: pw.Text(settings.shopAddress, textAlign: pw.TextAlign.center, style: const pw.TextStyle(color: PdfColors.blue, fontSize: 11))),
                  ]),
                ),
                
                pw.Divider(color: PdfColors.blue, thickness: 1),
                
                // 2. Info Row
                pw.Container(
                   padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                   child: pw.Row(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                       pw.Expanded(
                         flex: 1,
                         child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                           pw.Text('Bill No. : ${invoice.invoiceNo}', style: const pw.TextStyle(fontSize: 11)),
                           pw.Text('Date : ${invoice.date.toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 11)),
                         ])
                       ),
                       pw.Expanded(
                         flex: 2,
                         child: pw.Container(
                           decoration: const pw.BoxDecoration(
                               border: pw.Border(left: pw.BorderSide(color: PdfColors.blue))
                           ),
                           padding: const pw.EdgeInsets.only(left: 10),
                           child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                             pw.Text('To:', style: const pw.TextStyle(fontSize: 11)),
                             pw.Text(invoice.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                             if(invoice.customerAddress.isNotEmpty) pw.Text(invoice.customerAddress, style: const pw.TextStyle(fontSize: 11)),
                             if(invoice.buyerGst.isNotEmpty) pw.Text('GSTIN: ${invoice.buyerGst}', style: const pw.TextStyle(fontSize: 11)),
                           ])
                         )
                       ),
                     ]
                   )
                ),
                
                pw.Divider(color: PdfColors.blue, thickness: 1, height: 1),
                // 3. Table Header
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  child: pw.Row(children: [
                     pw.Expanded(flex: 4, child: pw.Padding(padding: const pw.EdgeInsets.only(left:5), child: pw.Text("Particulars", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),
                     pw.Expanded(flex: 1, child: pw.Center(child: pw.Text("HSN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),
                     pw.Expanded(flex: 1, child: pw.Center(child: pw.Text("No.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),
                     pw.Expanded(flex: 2, child: pw.Padding(padding: const pw.EdgeInsets.only(right:5), child: pw.Text("Amount", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),
                  ])
                ),
                pw.Divider(color: PdfColors.blue, thickness: 1, height: 1),
                
                // 4. Table Content
                pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Particulars
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.blue))),
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                ...invoice.items.map((e) => pw.Text(e.particulars, style: const pw.TextStyle(fontSize: 11))),
                                pw.Spacer(),
                                pw.Text("Sub Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                pw.SizedBox(height: 4),
                                pw.Text("CGST @ $cgstPercent%", style: const pw.TextStyle(fontSize: 11)),
                                pw.Text("SGST @ $sgstPercent%", style: const pw.TextStyle(fontSize: 11)),
                                pw.Text("Round Off", style: const pw.TextStyle(fontSize: 11)),
                              ]
                            )
                          )
                        ),
                        // HSN
                        pw.Expanded(flex: 1, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.blue))), child: pw.Column(children: []))),
                        // No
                        pw.Expanded(flex: 1, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.blue))), child: pw.Column(children: []))),
                        // Amount
                        pw.Expanded(
                          flex: 2,
                          child: pw.Container(
                             padding: const pw.EdgeInsets.all(5),
                             child: pw.Column(
                               crossAxisAlignment: pw.CrossAxisAlignment.end,
                               children: [
                                  ...invoice.items.map((e) => pw.Text(e.amount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 11))),
                                  pw.Spacer(),
                                  pw.Text(invoice.subTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(cgstAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 11)),
                                  pw.Text(sgstAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 11)),
                                  pw.Text("0.00", style: const pw.TextStyle(fontSize: 11)),
                               ]
                             )
                          )
                        ),
                      ]
                    )
                ),
                
                pw.Divider(color: PdfColors.blue, thickness: 1, height: 1),
                
                // 5. Grand Total
                 pw.Container(
                   decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue))),
                   padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                   child: pw.Row(
                     mainAxisAlignment: pw.MainAxisAlignment.end,
                     children: [
                       pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                       pw.SizedBox(width: 20),
                       pw.Text(invoice.grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                     ]
                   )
                 ),
                // 6. Footer
                pw.Container(
                  height: 120,
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                             pw.Text("Rupees : ${getNumberWords(invoice.grandTotal)}", style: const pw.TextStyle(fontSize: 11)),
                             pw.SizedBox(height: 10),
                             pw.Text("Declaration:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ...settings.declaration.split('\n').map((d) => pw.Text("• $d", style: const pw.TextStyle(fontSize: 9))),
                           ]
                         )
                       ),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text("For ${settings.shopName}", style: pw.TextStyle(color: PdfColors.blue, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            pw.SizedBox(height: 30),
                            pw.Text("PROPRIETOR", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ]
                        )
                      )
                    ]
                  )
                )
              ],
            ),
          );
        },
      ),
    );
    return await doc.save();
  }
  // Restore the missing static method for Ledgers
  static Future<Uint8List> generateLedgerBytes({
    required String title,
    required String subTitle,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, String> totals,
    required String? businessName,
    required String? logoPath,
    Map<int, pw.Alignment>? cellAlignments,
    List<List<String>>? monthlySummaryData,
    List<String>? monthlySummaryHeaders,
  }) async {
    // Sanitize Data (Replace Rupee Symbol to avoid font issues)
    final cleanData = data.map((row) => row.map((cell) => cell.replaceAll('₹', 'Rs. ')).toList()).toList();
    final cleanTotals = totals.map((key, value) => MapEntry(key, value.replaceAll('₹', 'Rs. ')));
    final cleanMonthlySummary = monthlySummaryData?.map((row) => row.map((cell) => cell.replaceAll('₹', 'Rs. ')).toList()).toList();

    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pw.Font? fontTamilRegular;
    pw.Font? fontTamilBold;
    try {
      fontTamilRegular = await PdfGoogleFonts.notoSansTamilRegular();
      fontTamilBold = await PdfGoogleFonts.notoSansTamilBold();
    } catch (_) {}

    final headerImageBytes = await _getHeaderImageBytes();
    final logoBytes = await _getLogoImageBytes(logoPath);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: const PdfPageFormat(595.28, 841.89, marginAll: 0),
          margin: pw.EdgeInsets.zero,
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
            fontFallback: [
              if (fontTamilRegular != null) fontTamilRegular,
              if (fontTamilBold != null) fontTamilBold,
            ],
          ),
        ),
        header: (pw.Context context) {
          return _buildHeaderBanner(
            headerImageBytes: headerImageBytes,
            logoBytes: logoBytes,
            width: 595.28,
          );
        },
        footer: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('App by Aandavar Solutions', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final bool is10Col = headers.length >= 10;
          final bool is9Col = headers.length == 9;
          final bool is8Col = headers.length == 8;
          final double fontSize = is10Col ? 6.2 : (is9Col ? 6.5 : (is8Col ? 7.5 : 8.5));
          final double headerFontSize = is10Col ? 7.0 : (is9Col ? 7.5 : (is8Col ? 8.0 : 9.0));

          return [
            pw.SizedBox(height: 4),
            _buildDocTitleBanner(title),
            if (subTitle.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Center(
                  child: pw.Text(subTitle, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                ),
              ),
            ],
            pw.SizedBox(height: 6),

            // Optional Monthly Summary Table
            if (cleanMonthlySummary != null && cleanMonthlySummary.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MONTH-BY-MONTH ATTENDANCE & SALARY BREAKDOWN', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      border: const pw.TableBorder(
                        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                        bottom: pw.BorderSide(color: PdfColors.indigo700, width: 1),
                        top: pw.BorderSide(color: PdfColors.indigo700, width: 1),
                      ),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                          children: (monthlySummaryHeaders ?? ['Month', 'Present', 'Absent', 'Earnings', 'Paid', 'Advance Given', 'Balance'])
                              .map((h) => pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white)),
                                  ))
                              .toList(),
                        ),
                        ...cleanMonthlySummary.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final row = entry.value;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.white : PdfColors.indigo50),
                            children: row
                                .map((cell) => pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                                      alignment: pw.Alignment.center,
                                      child: pw.Text(cell, style: const pw.TextStyle(fontSize: 7.5)),
                                    ))
                                .toList(),
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 6),
                  ],
                ),
              ),
            ],

            // Table with rich colors
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Table(
                columnWidths: is10Col ? const {
                  0: pw.FlexColumnWidth(0.9), // Date
                  1: pw.FlexColumnWidth(1.0), // Vehicle Details (Type \n No)
                  2: pw.FlexColumnWidth(0.6), // Bill No
                  3: pw.FlexColumnWidth(1.2), // Hours/Day & Rate
                  4: pw.FlexColumnWidth(0.9), // Rent
                  5: pw.FlexColumnWidth(1.3), // Material Details
                  6: pw.FlexColumnWidth(0.95), // Material Cost
                  7: pw.FlexColumnWidth(0.75), // Bata
                  8: pw.FlexColumnWidth(1.1), // Description
                  9: pw.FlexColumnWidth(1.0), // Amount
                } : (is9Col ? const {
                  0: pw.FlexColumnWidth(1.0), // Date
                  1: pw.FlexColumnWidth(1.1), // Vehicle Details (Type \n No)
                  2: pw.FlexColumnWidth(0.7), // Bill No
                  3: pw.FlexColumnWidth(1.5), // Hours/Day & Rate
                  4: pw.FlexColumnWidth(0.8), // Rate
                  5: pw.FlexColumnWidth(1.4), // Material Details
                  6: pw.FlexColumnWidth(0.7), // Bata
                  7: pw.FlexColumnWidth(1.1), // Description
                  8: pw.FlexColumnWidth(1.0), // Amount
                } : (is8Col ? const {
                  0: pw.FlexColumnWidth(1.2), // Date
                  1: pw.FlexColumnWidth(1.2), // Vehicle Type
                  2: pw.FlexColumnWidth(1.3), // Vehicle No
                  3: pw.FlexColumnWidth(1.0), // Bill No
                  4: pw.FlexColumnWidth(1.2), // Hours/Day
                  5: pw.FlexColumnWidth(1.1), // Rate
                  6: pw.FlexColumnWidth(1.0), // Bata
                  7: pw.FlexColumnWidth(1.3), // Amount
                } : null)),
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                    children: headers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final h = entry.value;
                      final align = cellAlignments?[idx] ?? pw.Alignment.centerLeft;
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        alignment: align,
                        child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: headerFontSize, color: PdfColors.white)),
                      );
                    }).toList(),
                  ),
                  // Data Rows
                  ...cleanData.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;
                    final isEven = rowIndex % 2 == 0;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : PdfColors.indigo50),
                      children: row.asMap().entries.map((cellEntry) {
                        final colIndex = cellEntry.key;
                        final cellValue = cellEntry.value;
                        final align = cellAlignments?[colIndex] ?? pw.Alignment.centerLeft;

                        PdfColor textColor = PdfColors.black;
                        pw.FontWeight weight = pw.FontWeight.normal;

                        if (cellValue.startsWith('--')) {
                          textColor = PdfColors.indigo900;
                          weight = pw.FontWeight.bold;
                        } else if (colIndex == 1) { // Attendance / Type Column
                          if (cellValue.contains('Present')) {
                            textColor = PdfColors.green700;
                            weight = pw.FontWeight.bold;
                          } else if (cellValue.contains('Absent')) {
                            textColor = PdfColors.red700;
                            weight = pw.FontWeight.bold;
                          } else if (cellValue.contains('Salary')) {
                            textColor = PdfColors.blue700;
                            weight = pw.FontWeight.bold;
                          }
                        } else if (colIndex == 2) { // Payment Mode Column
                          if (cellValue != '-') {
                            textColor = PdfColors.purple700;
                            weight = pw.FontWeight.bold;
                          } else {
                            textColor = PdfColors.grey600;
                          }
                        } else if (colIndex == 3 || colIndex == (headers.length - 1)) { // Amount Column
                          if (cellValue.startsWith('-')) {
                            textColor = PdfColors.red700;
                            weight = pw.FontWeight.bold;
                          } else if (cellValue.startsWith('+')) {
                            textColor = PdfColors.green700;
                            weight = pw.FontWeight.bold;
                          }
                        }

                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          alignment: align,
                          child: pw.Text(
                            cellValue, 
                            style: pw.TextStyle(fontSize: fontSize, color: textColor, fontWeight: weight)
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ],
              ),
            ),
            
            pw.SizedBox(height: 12),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            ),
            pw.SizedBox(height: 6),
            
            // Totals Section
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side: ONLY Advance Box Summary (if advance details exist)
                  if (cleanTotals.entries.any((e) => e.key.toLowerCase().contains('advance')))
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.orange300, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: cleanTotals.entries
                            .where((e) => e.key.toLowerCase().contains('advance'))
                            .map((e) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                            child: pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text('${e.key}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.orange900)),
                                pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.orange900)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  else
                    pw.SizedBox(),

                  // Right Side: General Totals (Present/Absent Days, Earnings, Paid, Net Balance)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: cleanTotals.entries
                        .where((e) => !e.key.toLowerCase().contains('advance'))
                        .map((e) {
                      final isBalance = e.key.toLowerCase().contains('balance');
                      final color = isBalance ? PdfColors.indigo900 : PdfColors.black;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('${e.key}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: color)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return await doc.save();
  }

  static Future<void> generateLedgerPdf({
    required String title,
    required String subTitle,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, String> totals,
    required String? businessName,
    required String? logoPath,
    Map<int, pw.Alignment>? cellAlignments,
    List<List<String>>? monthlySummaryData,
    List<String>? monthlySummaryHeaders,
  }) async {
    final bytes = await generateLedgerBytes(
      title: title, 
      subTitle: subTitle, 
      headers: headers, 
      data: data, 
      totals: totals, 
      businessName: businessName, 
      logoPath: logoPath,
      cellAlignments: cellAlignments,
      monthlySummaryData: monthlySummaryData,
      monthlySummaryHeaders: monthlySummaryHeaders,
    );

    // Save to Documents\Jarvis PDFs and auto-open
    await _saveAndOpenPdf(bytes, title);
  }

  static Future<void> saveLedgerPdf({
    required String title,
    required String subTitle,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, String> totals,
    required String? businessName,
    required String? logoPath,
    Map<int, pw.Alignment>? cellAlignments,
    List<List<String>>? monthlySummaryData,
    List<String>? monthlySummaryHeaders,
  }) async {
     final bytes = await generateLedgerBytes(
      title: title, 
      subTitle: subTitle, 
      headers: headers, 
      data: data, 
      totals: totals, 
      businessName: businessName, 
      logoPath: logoPath,
      cellAlignments: cellAlignments,
      monthlySummaryData: monthlySummaryData,
      monthlySummaryHeaders: monthlySummaryHeaders,
    );
    
    await Printing.sharePdf(bytes: bytes, filename: '${title.replaceAll(' ', '_')}.pdf');
  }

  static Future<File> getLedgerPdfFile({
    required String title,
    required String subTitle,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, String> totals,
    required String? businessName,
    required String? logoPath,
    Map<int, pw.Alignment>? cellAlignments,
    List<List<String>>? monthlySummaryData,
    List<String>? monthlySummaryHeaders,
  }) async {
     final bytes = await generateLedgerBytes(
      title: title, 
      subTitle: subTitle, 
      headers: headers, 
      data: data, 
      totals: totals, 
      businessName: businessName, 
      logoPath: logoPath,
      cellAlignments: cellAlignments,
      monthlySummaryData: monthlySummaryData,
      monthlySummaryHeaders: monthlySummaryHeaders,
    );
     
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${title.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> shareLedgerPdf({
    required String title,
    required String subTitle,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, String> totals,
    required String? businessName,
    required String? logoPath,
    Map<int, pw.Alignment>? cellAlignments,
    List<List<String>>? monthlySummaryData,
    List<String>? monthlySummaryHeaders,
  }) async {
    final file = await getLedgerPdfFile(
      title: title, subTitle: subTitle, headers: headers, 
      data: data, totals: totals, businessName: businessName, 
      logoPath: logoPath, cellAlignments: cellAlignments,
      monthlySummaryData: monthlySummaryData,
      monthlySummaryHeaders: monthlySummaryHeaders,
    );

    final String bName = (businessName != null && businessName.isNotEmpty) ? businessName : 'Aandavar Solutions';
    String textSummary = "*$bName*\n*$title*\n$subTitle\n\n";
    for (var row in data.take(25)) {
      textSummary += row.join(' | ') + '\n';
    }
    if (totals.isNotEmpty) {
      textSummary += '\n*Totals:*\n';
      totals.forEach((k, v) => textSummary += '$k: $v\n');
    }

    try {
      await Clipboard.setData(ClipboardData(text: textSummary));
    } catch (_) {}

    await openWhatsAppWithFile(file.path);
    await Share.shareXFiles([XFile(file.path)], text: textSummary);
  }

  static Future<bool> openWhatsAppWithFile(String filePath) async {
    try {
      if (Platform.isWindows) {
        final psCmd = "Add-Type -AssemblyName System.Windows.Forms; \$col = New-Object System.Collections.Specialized.StringCollection; \$col.Add('$filePath'); [System.Windows.Forms.Clipboard]::SetFileDropList(\$col)";
        await Process.run('powershell', ['-NoLogo', '-NoProfile', '-Command', psCmd]);
      }
      final Uri whatsappUrl = Uri.parse('whatsapp://');
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
        return true;
      } else {
        await launchUrl(Uri.parse('https://web.whatsapp.com'));
        return true;
      }
    } catch (e) {
      print('Error copying to clipboard: $e');
      return false;
    }
  }

  static Future<void> showShareDialog(
    BuildContext context, 
    File file, {
    String title = 'Share PDF', 
    String? textSummary,
  }) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Choose how you want to send this file.'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(file.path)], text: title);
            },
            icon: const Icon(Icons.share),
            label: const Text('Windows Share'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              if (textSummary != null && textSummary.isNotEmpty) {
                try {
                  await Clipboard.setData(ClipboardData(text: textSummary));
                } catch (_) {}
              }
              final success = await openWhatsAppWithFile(file.path);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 File & Text Copied! Select Contact in WhatsApp and Press Ctrl+V'),
                    duration: Duration(seconds: 5),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Use WhatsApp (Copy & Paste)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  static double _parseAmount(dynamic val) {
    if (val == null) return 0;
    String clean = val.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean) ?? 0;
  }

  static Future<void> generateDetailedVehicleSummaryPdf({
    required String title,
    required String subTitle,
    required List<Map<String, dynamic>> summaryData,
    required bool includeMaterialProfit,
    required Map<String, String> totals,
    required String? businessName,
    required String? logoPath,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pw.Font? fontTamilRegular;
    pw.Font? fontTamilBold;
    try {
      fontTamilRegular = await PdfGoogleFonts.notoSansTamilRegular();
      fontTamilBold = await PdfGoogleFonts.notoSansTamilBold();
    } catch (_) {}

    final headerImageBytes = await _getHeaderImageBytes();
    final logoBytes = await _getLogoImageBytes(logoPath);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: const PdfPageFormat(595.28, 841.89, marginAll: 0),
          margin: pw.EdgeInsets.zero,
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
            fontFallback: [
              if (fontTamilRegular != null) fontTamilRegular,
              if (fontTamilBold != null) fontTamilBold,
            ],
          ),
        ),
        header: (pw.Context context) {
          return _buildHeaderBanner(
            headerImageBytes: headerImageBytes,
            logoBytes: logoBytes,
            width: 595.28,
          );
        },
        footer: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('App by Aandavar Solutions', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> elements = [];

          elements.add(pw.SizedBox(height: 4));
          elements.add(_buildDocTitleBanner(title));
          if (subTitle.trim().isNotEmpty) {
            elements.add(pw.SizedBox(height: 3));
            elements.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Center(
                child: pw.Text(subTitle, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              ),
            ));
          }
          elements.add(pw.SizedBox(height: 6));

          // Overall Totals
          elements.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: totals.entries.map((e) => pw.Column(
                  children: [
                    pw.Text(e.key, style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 2),
                    pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ]
                )).toList(),
              )
            )
          );
          elements.add(pw.SizedBox(height: 8));

          // Vehicles
          for (var item in summaryData) {
            final netProfit = (item['net_profit'] as num).toDouble();
            final isProfit = netProfit >= 0;

            // Vehicle Section Header
            elements.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('VEHICLE: ${item['vehicle_no']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                    pw.Text(
                      'Net Profit: Rs. ${netProfit.toStringAsFixed(0)}', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: isProfit ? PdfColors.green700 : PdfColors.red700)
                    ),
                  ]
                ),
              )
            );
            // Vehicle Stats Summary Row
            elements.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Trips: ${item['total_trips']} | Income (Rent+Material): Rs. ${(item['trip_income'] as num).toStringAsFixed(0)} | Mat. Expense: Rs. ${(item['material_expense'] as num).toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Fuel: Rs. ${(item['fuel_expense'] as num).toStringAsFixed(0)} | Maint: Rs. ${(item['maintenance_expense'] as num).toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                  ]
                )
              )
            );
            elements.add(pw.SizedBox(height: 5));

            // Sort chronologically
            final List<Map<String, dynamic>> transactions = [];

            // Add Trips
            if (item['trips'] != null) {
              for (var t in (item['trips'] as List)) {
                final dateStr = t['date'] ?? '';
                DateTime dateVal = DateTime.now();
                try {
                  dateVal = DateFormat('dd MMM yyyy').parse(dateStr);
                } catch (_) {}

                final customer = t['customer']?.toString().isNotEmpty == true ? t['customer'].toString() : (t['site'] ?? 'General');
                double rentAmt = _parseAmount(t['rent_amount'] ?? t['total']);
                double battaAmt = _parseAmount(t['batta_amount'] ?? t['batta']);
                double totalAmt = _parseAmount(t['total']);
                
                String particulars = customer;
                String materialNameDisplay = '-';
                String qtyDisplay = '-';
                final materialName = t['material_name']?.toString().trim();
                final qty = _parseAmount(t['quantity']);
                
                double materialCost = 0.0;
                double materialExpenseVal = 0.0;
                if (materialName != null && materialName.isNotEmpty && qty > 0) {
                  materialNameDisplay = materialName;
                  final unitStr = t['unit']?.toString().trim() ?? '';
                  qtyDisplay = '${qty.toStringAsFixed(0)}${unitStr.isNotEmpty ? ' $unitStr' : ''}';
                  double sell = _parseAmount(t['unit_price']);
                  double buy = _parseAmount(t['buy_price']);
                  materialCost = sell * qty; // Material Cost is Sell Price
                  materialExpenseVal = buy * qty; // Buy cost is the expense
                }

                transactions.add({
                  'date': dateVal,
                  'dateStr': dateStr,
                  'vehicleNo': item['vehicle_no'] ?? '-',
                  'particulars': particulars,
                  'materialName': materialNameDisplay,
                  'qty': qtyDisplay,
                  'materialCost': materialCost,
                  'materialExpense': materialExpenseVal,
                  'tripCost': rentAmt,
                  'battaCost': battaAmt,
                  'isExpense': false,
                  'amount': totalAmt, // Gross Total Income from Customer
                });
              }
            }

            // Add Expenses
            if (item['expenses'] != null) {
              for (var e in (item['expenses'] as List)) {
                final dateStr = e['date'] ?? '';
                DateTime dateVal = DateTime.now();
                try {
                  dateVal = DateFormat('dd MMM yyyy').parse(dateStr);
                } catch (_) {}

                final desc = e['description'] ?? 'Expense';
                final supplier = e['supplier']?.toString() ?? '';
                final amt = _parseAmount(e['amount']);

                final descLower = desc.toLowerCase();
                final supLower = supplier.toLowerCase();
                String expType = 'Maintenance';
                if (descLower.contains('fuel') || descLower.contains('diesel') || descLower.contains('petrol') || descLower.contains('bunk') ||
                    supLower.contains('fuel') || supLower.contains('diesel') || supLower.contains('petrol') || supLower.contains('bunk')) {
                  expType = 'Fuel';
                }

                // Show supplier name for expense (per user request: "expense na supplier name mattum kudu pothum")
                String particulars = supplier.isNotEmpty ? supplier : desc;
                particulars = '$particulars ($expType)';

                transactions.add({
                  'date': dateVal,
                  'dateStr': dateStr,
                  'vehicleNo': item['vehicle_no'] ?? '-',
                  'particulars': particulars,
                  'materialName': '-',
                  'qty': '-',
                  'materialCost': 0.0,
                  'tripCost': 0.0,
                  'battaCost': 0.0,
                  'isExpense': true,
                  'amount': amt,
                });
              }
            }

            // Sort chronologically
            transactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

            double totalMaterialCostVal = 0; // Sell Price
            double totalMaterialExpenseVal = 0; // Buy Price (expense)
            double totalTripCostVal = 0;
            double totalBattaCostVal = 0;
            double totalExpenseVal = 0;
            double totalIncomeVal = 0;

            for (var tx in transactions) {
              if (tx['isExpense'] as bool) {
                totalExpenseVal += tx['amount'] as double;
              } else {
                totalMaterialCostVal += tx['materialCost'] as double;
                totalMaterialExpenseVal += (tx['materialExpense'] ?? 0.0) as double;
                totalTripCostVal += tx['tripCost'] as double;
                totalBattaCostVal += (tx['battaCost'] ?? 0.0) as double;
                totalIncomeVal += tx['amount'] as double;
              }
            }
            double netProfitVal = totalIncomeVal - totalExpenseVal - totalMaterialExpenseVal;

            if (transactions.isNotEmpty) {
              elements.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, top: 5, bottom: 4),
                child: pw.Text('Ledger Statement:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900))
              ));

              final List<String> headers = ['Date', 'Customer/Site', 'Material', 'Qty', 'Trip Cost', 'Batta', 'Material Cost', 'Amount'];

              elements.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(42),
                      1: pw.FlexColumnWidth(),
                      2: pw.FixedColumnWidth(50),
                      3: pw.FixedColumnWidth(35),
                      4: pw.FixedColumnWidth(48),
                      5: pw.FixedColumnWidth(42),
                      6: pw.FixedColumnWidth(48),
                      7: pw.FixedColumnWidth(48),
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: headers.map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        )).toList(),
                      ),
                      // Data Rows
                      ...transactions.map((tx) {
                        final isExpense = tx['isExpense'] as bool;
                        final amtText = (isExpense ? '-' : '+') + 'Rs. ${(tx['amount'] as double).toStringAsFixed(0)}';
                        final amtColor = isExpense ? PdfColors.red700 : PdfColors.green700;

                        final cells = [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx['dateStr'], style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx['particulars'], style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx['materialName'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx['qty'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx['tripCost'] > 0 ? 'Rs. ${(tx['tripCost'] as double).toStringAsFixed(0)}' : '-', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text((tx['battaCost'] ?? 0) > 0 ? 'Rs. ${((tx['battaCost'] ?? 0) as double).toStringAsFixed(0)}' : '-', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx['materialCost'] > 0 ? 'Rs. ${(tx['materialCost'] as double).toStringAsFixed(0)}' : '-', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(amtText, style: pw.TextStyle(fontSize: 8, color: amtColor, fontWeight: pw.FontWeight.bold)),
                            )
                          ),
                        ];

                        return pw.TableRow(children: cells);
                      }).toList(),
                      // Totals Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs. ${totalTripCostVal.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs. ${totalBattaCostVal.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs. ${totalMaterialCostVal.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                (netProfitVal >= 0 ? '+' : '') + 'Rs. ${netProfitVal.toStringAsFixed(0)}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: netProfitVal >= 0 ? PdfColors.green700 : PdfColors.red700)
                              )
                            )
                          ),
                        ]
                      )
                    ]
                  )
                )
              );
            }
            
            elements.add(pw.SizedBox(height: 10));
            elements.add(pw.Divider(color: PdfColors.grey400, thickness: 1));
          }

          return elements;
        },
      ),
    );
    
    final bytes = await doc.save();
    // Save to Documents\Jarvis PDFs and auto-open
    await _saveAndOpenPdf(bytes, title);
  }

  /// Saves PDF bytes to Documents\Jarvis PDFs\ and opens it with the default viewer.
  static Future<void> _saveAndOpenPdf(Uint8List bytes, String title) async {
    try {
      // Get the user's Documents folder
      final String docsPath;
      if (Platform.isWindows) {
        docsPath = (Platform.environment['USERPROFILE'] ?? '') + r'\Documents';
      } else {
        final dir = await getTemporaryDirectory();
        docsPath = dir.path;
      }

      // Create Jarvis PDFs sub-folder if not exists
      final folderPath = '$docsPath\\Jarvis PDFs';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      // Write file
      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '$folderPath\\$safeName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Auto-copy generated PDF file to system Clipboard for instant pasting!
      if (Platform.isWindows) {
        try {
          final psCmd = "Add-Type -AssemblyName System.Windows.Forms; \$col = New-Object System.Collections.Specialized.StringCollection; \$col.Add('$filePath'); [System.Windows.Forms.Clipboard]::SetFileDropList(\$col)";
          await Process.run('powershell', ['-NoLogo', '-NoProfile', '-Command', psCmd]);
        } catch (_) {}
      }

      // Open with default PDF viewer
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else {
        await Process.run('xdg-open', [filePath]);
      }
    } catch (e) {
      // Fallback: use printing package share
      await Printing.sharePdf(bytes: bytes, filename: '${title.replaceAll(' ', '_')}.pdf');
    }
  }

  /// Generates and opens a simple Customer List PDF (Name | Phone | Address | Balance)
  static Future<void> generateCustomerListPdf({
    required List<Map<String, dynamic>> customers,
    required String businessName,
    required double Function(dynamic) parseAmount,
    bool preserveSort = true,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pw.Font? fontTamilRegular;
    pw.Font? fontTamilBold;
    try {
      fontTamilRegular = await PdfGoogleFonts.notoSansTamilRegular();
      fontTamilBold = await PdfGoogleFonts.notoSansTamilBold();
    } catch (_) {}

    final headerImageBytes = await _getHeaderImageBytes();
    final logoBytes = await _getLogoImageBytes();
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final sorted = preserveSort 
        ? List<Map<String, dynamic>>.from(customers)
        : (List<Map<String, dynamic>>.from(customers)
          ..sort((a, b) {
              final ba = parseAmount(a['balance']);
              final bb = parseAmount(b['balance']);
              return bb.compareTo(ba);
            }));

    double grandTotal = 0;
    for (var c in sorted) {
      grandTotal += parseAmount(c['balance']);
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: const PdfPageFormat(595.28, 841.89, marginAll: 0),
          margin: pw.EdgeInsets.zero,
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
            fontFallback: [
              if (fontTamilRegular != null) fontTamilRegular,
              if (fontTamilBold != null) fontTamilBold,
            ],
          ),
        ),
        header: (ctx) => _buildHeaderBanner(
          headerImageBytes: headerImageBytes,
          logoBytes: logoBytes,
          width: 595.28,
        ),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Customers: ${sorted.length}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 4),
          _buildDocTitleBanner('CUSTOMER BALANCE LIST', marginHorizontal: 18),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              'Printed on: $now',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 18),
            child: pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(25),
                1: pw.FlexColumnWidth(2.5),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(2.5),
                4: pw.FlexColumnWidth(2.0),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: pw.Text('S.No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: pw.Text('Customer Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: pw.Text('Phone', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: pw.Text('Address', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Balance (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white)),
                      ),
                    ),
                  ],
                ),
                // Data rows
                ...sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final bal = parseAmount(c['balance']);
                  final isEven = i % 2 == 0;
                  final addr = (c['address'] != null && c['address'].toString().trim().isNotEmpty) ? c['address'].toString().trim() : '-';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.indigo50,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        child: pw.Text(c['name'] ?? '', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        child: pw.Text(c['phone'] ?? '-', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        child: pw.Text(addr, style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            'Rs. ${bal.toInt()}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: bal > 0 ? PdfColors.red700 : PdfColors.green700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                // Grand total row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8.5))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8.5))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          'Rs. ${grandTotal.toInt()}',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: grandTotal > 0 ? PdfColors.red700 : PdfColors.green700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await _saveAndOpenPdf(bytes, 'Customer_Balance_List');
  }

  Future<void> generateDailyVehicleReportPdf({
    required List<Map<String, dynamic>> reportRows,
    required String dateRangeTitle,
    required String businessName,
    bool share = false,
    BuildContext? context,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pw.Font? fontTamilRegular;
    pw.Font? fontTamilBold;
    try {
      fontTamilRegular = await PdfGoogleFonts.notoSansTamilRegular();
      fontTamilBold = await PdfGoogleFonts.notoSansTamilBold();
    } catch (_) {}

    final headerImageBytes = await _getHeaderImageBytes();
    final logoBytes = await _getLogoImageBytes();

    final yellowHeaderColor = PdfColor.fromHex('#FACC15'); // Bright Yellow Header #FACC15

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: const PdfPageFormat(841.89, 595.28, marginAll: 0),
          margin: pw.EdgeInsets.zero,
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
            fontFallback: [
              if (fontTamilRegular != null) fontTamilRegular,
              if (fontTamilBold != null) fontTamilBold,
            ],
          ),
        ),
        header: (pw.Context context) {
          return _buildHeaderBanner(
            headerImageBytes: headerImageBytes,
            logoBytes: logoBytes,
            width: 841.89,
          );
        },
        footer: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('App by Aandavar Solutions', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final List<String> headers = [
            'S.No', 'Vehicle', 'Vehicle No', 'Driver', 'Bill No', 'Date', 
            'Party Name', 'Place', 'Phone No', 'Time', 'Diesel', 'Status', 'Details'
          ];

          return [
            pw.SizedBox(height: 4),
            _buildDocTitleBanner('DAILY VEHICLE REPORT', marginHorizontal: 16),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text('Period: $dateRangeTitle', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            ),
            pw.SizedBox(height: 6),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(28), // S.No
                  1: pw.FlexColumnWidth(1.2), // Vehicle
                  2: pw.FlexColumnWidth(1.5), // Vehicle No
                  3: pw.FlexColumnWidth(1.4), // Driver
                  4: pw.FixedColumnWidth(36), // Bill No
                  5: pw.FlexColumnWidth(1.3), // Date
                  6: pw.FlexColumnWidth(1.8), // Party Name
                  7: pw.FlexColumnWidth(1.6), // Place
                  8: pw.FlexColumnWidth(1.3), // Phone No
                  9: pw.FixedColumnWidth(42), // Time
                  10: pw.FixedColumnWidth(40), // Diesel
                  11: pw.FlexColumnWidth(1.5), // Status
                  12: pw.FlexColumnWidth(1.6), // Details
                },
                children: [
                  // Yellow Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: yellowHeaderColor),
                    children: headers.map((h) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                  // Data Rows
                  ...reportRows.map((row) {
                    return pw.TableRow(
                      children: [
                        _buildPdfTableCell(row['s_no'].toString(), align: pw.TextAlign.center),
                        _buildPdfTableCell(row['vehicle'].toString()),
                        _buildPdfTableCell(row['vehicle_no'].toString()),
                        _buildPdfTableCell(row['driver'].toString()),
                        _buildPdfTableCell(row['bill_no'].toString(), align: pw.TextAlign.center),
                        _buildPdfTableCell(row['date'].toString(), align: pw.TextAlign.center),
                        _buildPdfTableCell(row['party_name'].toString()),
                        _buildPdfTableCell(row['place'].toString()),
                        _buildPdfTableCell(row['phone_no'].toString(), align: pw.TextAlign.center),
                        _buildPdfTableCell(row['time'].toString(), align: pw.TextAlign.center),
                        _buildPdfTableCell(row['diesel'].toString(), align: pw.TextAlign.right),
                        _buildPdfTableCell(row['status'].toString()),
                        _buildPdfTableCell(row['details'].toString()),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    if (share) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Daily_Vehicle_Report.pdf');
      await file.writeAsBytes(bytes);
      if (context != null) {
        await showShareDialog(context, file, title: 'Share Daily Vehicle Report PDF');
      } else {
        await Share.shareXFiles([XFile(file.path)], text: 'Daily Vehicle Report - $dateRangeTitle');
      }
    } else {
      await _saveAndOpenPdf(bytes, 'Daily_Vehicle_Report_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  pw.Widget _buildPdfTableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7.5),
        textAlign: align,
      ),
    );
  }

  // --- CUSTOMER ACCOUNT STATEMENT PDF GENERATION ---
  static Future<Uint8List> generateCustomerAccountStatementBytes({
    required String customerName,
    required String customerAddress,
    required List<List<String>> dataRows,
    required Map<String, String> totals,
    List<List<String>>? paymentRows,
    String? shopNameTamil,
    String? shopSubTitleTamil,
    String? shopAddressTamil,
    String? contactPhone,
    String? logoPath,
    String? headerImagePath,
  }) async {
    final cleanData = dataRows.map((row) => row.map((cell) => cell.replaceAll('₹', '')).toList()).toList();
    final cleanTotals = totals.map((key, value) => MapEntry(key, value.replaceAll('₹', 'Rs. ')));
    final cleanPayments = paymentRows?.map((row) => row.map((cell) => cell.replaceAll('₹', '')).toList()).toList();

    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pw.Font? fontTamilRegular;
    pw.Font? fontTamilBold;
    try {
      fontTamilRegular = await PdfGoogleFonts.notoSansTamilRegular();
      fontTamilBold = await PdfGoogleFonts.notoSansTamilBold();
    } catch (_) {}

    // Load header image
    Uint8List? headerImageBytes;
    final hPath = headerImagePath ?? 'assets/customer_header.png';
    if (File(hPath).existsSync()) {
      headerImageBytes = File(hPath).readAsBytesSync();
    } else {
      try {
        final ByteData data = await rootBundle.load(hPath);
        headerImageBytes = data.buffer.asUint8List();
      } catch (_) {}
    }
    print('PDF Service debug: headerImageBytes is ${headerImageBytes?.length} bytes, hPath: $hPath');

    // Load logo
    Uint8List? logoBytes;
    if (logoPath != null && File(logoPath).existsSync()) {
      logoBytes = File(logoPath).readAsBytesSync();
    } else {
      try {
        final ByteData data = await rootBundle.load('assets/logo.png');
        logoBytes = data.buffer.asUint8List();
      } catch (_) {}
    }

    final headers = ['S.No', 'Date', 'Vehicle Details', 'Rate type', 'Hours/Day', 'Rate', 'Batta', 'Material', 'Amount'];

    final tealColor = PdfColor.fromHex('#156D84');

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: const PdfPageFormat(595.28, 841.89, marginAll: 0),
          margin: pw.EdgeInsets.zero,
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
            fontFallback: [
              if (fontTamilRegular != null) fontTamilRegular,
              if (fontTamilBold != null) fontTamilBold,
            ],
          ),
        ),
        header: (pw.Context context) {
          return _buildHeaderBanner(
            headerImageBytes: headerImageBytes,
            logoBytes: logoBytes,
            shopNameTamil: shopNameTamil,
            shopSubTitleTamil: shopSubTitleTamil,
            shopAddressTamil: shopAddressTamil,
            contactPhone: contactPhone,
            width: 595.28,
          );
        },
        footer: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('App by Aandavar Solutions', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 4),
            _buildDocTitleBanner('CUSTOMER ACCOUNT STATEMENT'),
            pw.SizedBox(height: 6),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // "To," Section
                  pw.Text('To,', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 36),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('$customerName,', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if (customerAddress.isNotEmpty)
                          pw.SizedBox(height: 2),
                        if (customerAddress.isNotEmpty)
                          pw.Text('$customerAddress.', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Customer Name-Address Teal Banner Header
                  pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: tealColor,
                      border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    ),
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Center(
                      child: pw.Text(
                        customerAddress.isNotEmpty ? '$customerName-$customerAddress' : customerName,
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                ],
              ),
            ),

            // 9-Column Table that automatically splits across pages
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Table.fromTextArray(
                headers: headers,
                data: cleanData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
                headerCount: 1,
                columnWidths: const {
                  0: pw.FixedColumnWidth(28), // S.No
                  1: pw.FixedColumnWidth(52), // Date
                  2: pw.FixedColumnWidth(135), // Vehicle Details
                  3: pw.FixedColumnWidth(56), // Rate type
                  4: pw.FixedColumnWidth(58), // Hours/Day
                  5: pw.FixedColumnWidth(44), // Rate
                  6: pw.FixedColumnWidth(38), // Batta
                  7: pw.FixedColumnWidth(78), // Material
                  8: pw.FixedColumnWidth(62), // Amount
                },
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerLeft,
                  8: pw.Alignment.centerRight,
                },
                border: const pw.TableBorder(
                  left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                ),
              ),
            ),

            // Payment Details Box & Summary Totals at Bottom
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (cleanPayments != null && cleanPayments.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: double.infinity,
                            color: tealColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                            child: pw.Text(
                              'PAYMENT DETAILS',
                              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                            ),
                          ),
                          pw.Table.fromTextArray(
                            headers: ['S.No', 'Date', 'Description / Mode', 'Amount'],
                            data: cleanPayments,
                            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black),
                            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            cellStyle: const pw.TextStyle(fontSize: 8.5),
                            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            headerCount: 1,
                            columnWidths: const {
                              0: pw.FixedColumnWidth(28),
                              1: pw.FixedColumnWidth(65),
                              2: pw.FlexColumnWidth(1),
                              3: pw.FixedColumnWidth(80),
                            },
                            cellAlignments: {
                              0: pw.Alignment.center,
                              1: pw.Alignment.center,
                              2: pw.Alignment.centerLeft,
                              3: pw.Alignment.centerRight,
                            },
                            border: const pw.TableBorder(
                              top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                              horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
                              verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 260,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        ),
                        child: pw.Column(
                          children: cleanTotals.entries.map((e) {
                            final keyLower = e.key.toLowerCase();
                            final isBalance = keyLower.contains('balance');
                            final isPaid = keyLower.contains('paid');
                            final textColor = isBalance
                                ? PdfColors.red700
                                : (isPaid ? PdfColor.fromHex('#2e7d32') : PdfColors.black);
                            return pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(e.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: textColor)),
                                  pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: textColor)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return await doc.save();
  }

  static Future<void> generateCustomerAccountStatementPdf({
    required String customerName,
    required String customerAddress,
    required List<List<String>> dataRows,
    required Map<String, String> totals,
    List<List<String>>? paymentRows,
    String? shopNameTamil,
    String? shopSubTitleTamil,
    String? shopAddressTamil,
    String? contactPhone,
    String? logoPath,
  }) async {
    final bytes = await generateCustomerAccountStatementBytes(
      customerName: customerName,
      customerAddress: customerAddress,
      dataRows: dataRows,
      totals: totals,
      paymentRows: paymentRows,
      shopNameTamil: shopNameTamil,
      shopSubTitleTamil: shopSubTitleTamil,
      shopAddressTamil: shopAddressTamil,
      contactPhone: contactPhone,
      logoPath: logoPath,
    );
    await _saveAndOpenPdf(bytes, '${customerName}_Statement');
  }

  static Future<void> saveCustomerAccountStatementPdf({
    required String customerName,
    required String customerAddress,
    required List<List<String>> dataRows,
    required Map<String, String> totals,
    List<List<String>>? paymentRows,
    String? shopNameTamil,
    String? shopSubTitleTamil,
    String? shopAddressTamil,
    String? contactPhone,
    String? logoPath,
  }) async {
    final bytes = await generateCustomerAccountStatementBytes(
      customerName: customerName,
      customerAddress: customerAddress,
      dataRows: dataRows,
      totals: totals,
      paymentRows: paymentRows,
      shopNameTamil: shopNameTamil,
      shopSubTitleTamil: shopSubTitleTamil,
      shopAddressTamil: shopAddressTamil,
      contactPhone: contactPhone,
      logoPath: logoPath,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${customerName.replaceAll(' ', '_')}_Statement.pdf');
  }

  static Future<File> getCustomerAccountStatementPdfFile({
    required String customerName,
    required String customerAddress,
    required List<List<String>> dataRows,
    required Map<String, String> totals,
    List<List<String>>? paymentRows,
    String? shopNameTamil,
    String? shopSubTitleTamil,
    String? shopAddressTamil,
    String? contactPhone,
    String? logoPath,
  }) async {
    final bytes = await generateCustomerAccountStatementBytes(
      customerName: customerName,
      customerAddress: customerAddress,
      dataRows: dataRows,
      totals: totals,
      paymentRows: paymentRows,
      shopNameTamil: shopNameTamil,
      shopSubTitleTamil: shopSubTitleTamil,
      shopAddressTamil: shopAddressTamil,
      contactPhone: contactPhone,
      logoPath: logoPath,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${customerName.replaceAll(' ', '_')}_Statement.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }
}
