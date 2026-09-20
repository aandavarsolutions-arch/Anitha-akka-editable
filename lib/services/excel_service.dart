import 'package:excel/excel.dart';
import '../models/invoice.dart';
import '../models/shop_settings.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExcelService {
  Future<List<int>?> generateInvoice(Invoice invoice, ShopSettings settings) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    
    // Styling
    CellStyle boldStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true);
    
    // Header
    var cell = sheetObject.cell(CellIndex.indexByString("A1"));
    cell.value = TextCellValue(settings.shopName);
    cell.cellStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true, fontSize: 16);
    
    sheetObject.cell(CellIndex.indexByString("A2")).value = TextCellValue(settings.shopAddress);
    sheetObject.cell(CellIndex.indexByString("A3")).value = TextCellValue("GST: ${settings.sellerGst}");
    
    // Invoice Info
    sheetObject.cell(CellIndex.indexByString("A5")).value = TextCellValue("Invoice No:");
    sheetObject.cell(CellIndex.indexByString("B5")).value = TextCellValue(invoice.invoiceNo);
    
    sheetObject.cell(CellIndex.indexByString("A6")).value = TextCellValue("Date:");
    sheetObject.cell(CellIndex.indexByString("B6")).value = TextCellValue(invoice.date.toString().split(' ')[0]);
    
    sheetObject.cell(CellIndex.indexByString("D5")).value = TextCellValue("Bill To:");
    sheetObject.cell(CellIndex.indexByString("E5")).value = TextCellValue(invoice.customerName);
    sheetObject.cell(CellIndex.indexByString("D6")).value = TextCellValue("Buyer GST:");
    sheetObject.cell(CellIndex.indexByString("E6")).value = TextCellValue(invoice.buyerGst);

    // Table Headers
    List<String> headers = ["S.No", "Particulars", "Rate", "Amount"];
    for(int i=0; i<headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 8));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = boldStyle;
    }
    
    int rowIndex = 9;
    for (var i = 0; i < invoice.items.length; i++) {
        var item = invoice.items[i];
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(item.particulars);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = DoubleCellValue(item.rate);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(item.amount);
        rowIndex++;
    }
    
    rowIndex += 2;
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue("Subtotal");
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(invoice.subTotal);
    
    rowIndex++;
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue("GST (${invoice.gstPercentage}%)");
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(invoice.gstAmount);
    
    rowIndex++;
    var gtCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
    gtCell.value = TextCellValue("Grand Total");
    gtCell.cellStyle = boldStyle;
    
    var gtValCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
    gtValCell.value = DoubleCellValue(invoice.grandTotal);
    gtValCell.cellStyle = boldStyle;
    
    _autoFitColumns(excel);
    return excel.encode();
  }

  // Generates and opens 9-column Customer Account Statement Excel matching PDF table format (No top business header)
  static Future<void> generateCustomerAccountStatementExcel({
    required String customerName,
    required String customerAddress,
    String? customerPhone,
    required List<List<String>> dataRows,
    required Map<String, String> totals,
    List<List<String>>? paymentRows,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    CellStyle boldStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true);
    CellStyle subHeaderStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#156D84'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    int rowIndex = 0;

    // Customer Name Banner Row (Top of Excel Sheet - No business logo/header above)
    var cellBanner = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    String bannerStr = customerAddress.isNotEmpty ? 'To: $customerName, $customerAddress' : 'To: $customerName';
    if (customerPhone != null && customerPhone.isNotEmpty) {
      bannerStr += ' (Ph: $customerPhone)';
    }
    cellBanner.value = TextCellValue(bannerStr);
    cellBanner.cellStyle = subHeaderStyle;
    rowIndex += 2;

    final headers = ['S.No', 'Date', 'Vehicle Details', 'Rate type', 'Hours/Day', 'Rate', 'Batta', 'Material', 'Amount'];

    // Table Headers
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = boldStyle;
    }
    rowIndex++;

    // Data Rows
    for (var row in dataRows) {
      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
        cell.value = TextCellValue(row[colIndex].replaceAll('₹', ''));
      }
      rowIndex++;
    }

    // Payment Details Table
    if (paymentRows != null && paymentRows.isNotEmpty) {
      rowIndex += 2;
      var payBanner = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      payBanner.value = TextCellValue('PAYMENT DETAILS');
      payBanner.cellStyle = subHeaderStyle;
      rowIndex++;

      final payHeaders = ['S.No', 'Date', 'Description / Mode', 'Amount'];
      for (int i = 0; i < payHeaders.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
        cell.value = TextCellValue(payHeaders[i]);
        cell.cellStyle = boldStyle;
      }
      rowIndex++;

      for (var row in paymentRows) {
        for (int colIndex = 0; colIndex < row.length; colIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
          cell.value = TextCellValue(row[colIndex].replaceAll('₹', ''));
        }
        rowIndex++;
      }
    }

    // Totals at bottom right
    rowIndex += 1;
    totals.forEach((key, value) {
      var cellKey = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: headers.length - 2, rowIndex: rowIndex));
      cellKey.value = TextCellValue(key);
      cellKey.cellStyle = boldStyle;

      var cellVal = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: rowIndex));
      cellVal.value = TextCellValue(value.replaceAll('₹', 'Rs. '));
      cellVal.cellStyle = boldStyle;
      rowIndex++;
    });

    _autoFitColumns(excel);
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndOpenExcel(bytes, '${customerName}_Statement');
    }
  }

  // Generates and opens a Ledger Excel file
  static Future<void> generateLedgerExcel({
    required String title,
    required String subTitle,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, String> totals,
    required String? businessName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    CellStyle boldStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true);

    // Business & Title Header
    var cellBName = sheetObject.cell(CellIndex.indexByString("A1"));
    cellBName.value = TextCellValue(businessName ?? 'Aandavar Solutions');
    cellBName.cellStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true, fontSize: 14);

    var cellTitle = sheetObject.cell(CellIndex.indexByString("A2"));
    cellTitle.value = TextCellValue(title);
    cellTitle.cellStyle = boldStyle;

    var cellSub = sheetObject.cell(CellIndex.indexByString("A3"));
    cellSub.value = TextCellValue(subTitle);

    // Add Table Headers
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = boldStyle;
    }

    // Add Data Rows
    int rowIndex = 6;
    for (var row in data) {
      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
        cell.value = TextCellValue(row[colIndex].replaceAll('₹', 'Rs. '));
      }
      rowIndex++;
    }

    // Add Totals
    rowIndex += 2;
    totals.forEach((key, value) {
      var cellKey = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: headers.length - 2, rowIndex: rowIndex));
      cellKey.value = TextCellValue(key);
      cellKey.cellStyle = boldStyle;

      var cellVal = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: rowIndex));
      cellVal.value = TextCellValue(value.replaceAll('₹', 'Rs. '));
      cellVal.cellStyle = boldStyle;
      rowIndex++;
    });

    _autoFitColumns(excel);
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndOpenExcel(bytes, title);
    }
  }

  // Generates and opens a Customer List Excel
  static Future<void> generateCustomerListExcel({
    required List<Map<String, dynamic>> customers,
    required String businessName,
    required double Function(dynamic) parseAmount,
    bool preserveSort = true,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    CellStyle boldStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true);

    var cellBName = sheetObject.cell(CellIndex.indexByString("A1"));
    cellBName.value = TextCellValue(businessName.isNotEmpty ? businessName : 'Jarvis');
    cellBName.cellStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true, fontSize: 14);

    var cellTitle = sheetObject.cell(CellIndex.indexByString("A2"));
    cellTitle.value = TextCellValue("Customer Balance List");
    cellTitle.cellStyle = boldStyle;

    // Headers
    List<String> headers = ["S.No", "Customer Name", "Phone", "Address", "Balance (Rs.)"];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = boldStyle;
    }

    final sorted = preserveSort 
        ? List<Map<String, dynamic>>.from(customers)
        : (List<Map<String, dynamic>>.from(customers)
          ..sort((a, b) => parseAmount(b['balance']).compareTo(parseAmount(a['balance']))));

    double grandTotal = 0;
    int rowIndex = 5;

    for (int i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      final bal = parseAmount(c['balance']);
      grandTotal += bal;

      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(c['name'] ?? '');
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(c['phone'] ?? '-');
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue((c['address'] != null && c['address'].toString().trim().isNotEmpty) ? c['address'].toString().trim() : '-');
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(bal);
      rowIndex++;
    }

    // Grand Total Row
    rowIndex += 2;
    var cellLabel = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    cellLabel.value = TextCellValue("GRAND TOTAL");
    cellLabel.cellStyle = boldStyle;

    var cellVal = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
    cellVal.value = DoubleCellValue(grandTotal);
    cellVal.cellStyle = boldStyle;

    _autoFitColumns(excel);
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndOpenExcel(bytes, 'Customer_Balance_List');
    }
  }

  // Generates and opens Detailed Vehicle Summary Excel
  static Future<void> generateDetailedVehicleSummaryExcel({
    required String title,
    required String subTitle,
    required List<Map<String, dynamic>> summaryData,
    required bool includeMaterialProfit,
    required Map<String, String> totals,
    required String? businessName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    CellStyle boldStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true);

    // Title
    var cellBName = sheetObject.cell(CellIndex.indexByString("A1"));
    cellBName.value = TextCellValue(businessName ?? 'Business Name');
    cellBName.cellStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true, fontSize: 14);

    var cellTitle = sheetObject.cell(CellIndex.indexByString("A2"));
    cellTitle.value = TextCellValue(title);
    cellTitle.cellStyle = boldStyle;

    var cellSub = sheetObject.cell(CellIndex.indexByString("A3"));
    cellSub.value = TextCellValue(subTitle);

    // Overall Totals
    int rowIndex = 5;
    totals.forEach((key, value) {
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(key);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(value);
      rowIndex++;
    });

    rowIndex += 2;

    // Table Headers for Vehicle Ledger
    List<String> headers = ['Vehicle No', 'Date', 'Customer/Site', 'Material', 'Qty', 'Trip Cost', 'Batta', 'Material Cost', 'Amount'];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = boldStyle;
    }
    rowIndex++;

    // Populate data
    for (var item in summaryData) {
      final vehicleNo = item['vehicle_no'] ?? '-';
      final List<Map<String, dynamic>> transactions = [];

      // Add Trips
      if (item['trips'] != null) {
        for (var t in (item['trips'] as List)) {
          final dateStr = t['date'] ?? '';
          final customer = t['customer']?.toString().isNotEmpty == true ? t['customer'].toString() : (t['site'] ?? 'General');
          double sell = _parseAmount(t['unit_price']);
          double qty = _parseAmount(t['quantity']);
          double rentAmt = _parseAmount(t['rent_amount'] ?? t['total']);
          double battaAmt = _parseAmount(t['batta_amount'] ?? t['batta']);
          double totalAmt = _parseAmount(t['total']);
          final materialName = t['material_name']?.toString() ?? '-';

          transactions.add({
            'date': dateStr,
            'particulars': customer,
            'materialName': materialName,
            'qty': qty > 0 ? '$qty ${t['unit'] ?? ''}' : '-',
            'tripCost': rentAmt,
            'battaCost': battaAmt,
            'materialCost': sell * qty,
            'amount': totalAmt,
          });
        }
      }

      // Add Expenses
      if (item['expenses'] != null) {
        for (var e in (item['expenses'] as List)) {
          final dateStr = e['date'] ?? '';
          final desc = e['description'] ?? 'Expense';
          final supplier = e['supplier']?.toString() ?? '';
          final amt = _parseAmount(e['amount']);
          String expType = desc.toLowerCase().contains('fuel') ? 'Fuel' : 'Maintenance';
          String particulars = supplier.isNotEmpty ? '$supplier ($expType)' : '$desc ($expType)';

          transactions.add({
            'date': dateStr,
            'particulars': particulars,
            'materialName': '-',
            'qty': '-',
            'tripCost': 0.0,
            'battaCost': 0.0,
            'materialCost': 0.0,
            'amount': -amt,
          });
        }
      }

      // Sort
      for (var tx in transactions) {
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(vehicleNo);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(tx['date']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(tx['particulars']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(tx['materialName']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(tx['qty']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(tx['tripCost']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(tx['battaCost']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(tx['materialCost']);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(tx['amount']);
        rowIndex++;
      }
    }

    _autoFitColumns(excel);
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndOpenExcel(bytes, title);
    }
  }

  static double _parseAmount(dynamic val) {
    if (val == null) return 0;
    String clean = val.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean) ?? 0;
  }

  // Saves Excel bytes to Documents\Jarvis Excels\ and opens it
  static Future<void> _saveAndOpenExcel(List<int> bytes, String title) async {
    try {
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

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '$folderPath\\$safeName.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Auto-copy generated Excel file to system Clipboard for instant pasting!
      if (Platform.isWindows) {
        try {
          final psCmd = "Add-Type -AssemblyName System.Windows.Forms; \$col = New-Object System.Collections.Specialized.StringCollection; \$col.Add('$filePath'); [System.Windows.Forms.Clipboard]::SetFileDropList(\$col)";
          await Process.run('powershell', ['-NoLogo', '-NoProfile', '-Command', psCmd]);
        } catch (_) {}
      }

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else {
        await Process.run('xdg-open', [filePath]);
      }
    } catch (e) {
      print('Error saving/opening excel: $e');
    }
  }

  static void _autoFitColumns(Excel excel) {
    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      for (int i = 0; i < sheet.maxColumns; i++) {
        double maxLen = 12.0;
        for (int r = 0; r < sheet.maxRows; r++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: r));
          if (cell.value != null) {
            final cellStr = cell.value.toString();
            final lines = cellStr.split('\n');
            for (var line in lines) {
              final len = line.length * 1.35 + 3.0;
              if (len > maxLen) {
                maxLen = len;
              }
            }
          }
        }
        sheet.setColumnWidth(i, maxLen);
      }
    }
  }

  static Future<void> generateDailyVehicleReportExcel({
    required List<Map<String, dynamic>> reportRows,
    required String dateRangeTitle,
    required String businessName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Daily Report'];

    CellStyle headerStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#000000'),
      backgroundColorHex: ExcelColor.fromHexString('#FFFF00'),
    );

    // Business Header
    sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue(businessName);
    sheetObject.cell(CellIndex.indexByString("A1")).cellStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true, fontSize: 16);
    sheetObject.cell(CellIndex.indexByString("A2")).value = TextCellValue("DAILY VEHICLE REPORT - $dateRangeTitle");
    sheetObject.cell(CellIndex.indexByString("A2")).cellStyle = CellStyle(fontFamily: getFontFamily(FontFamily.Arial), bold: true, fontSize: 12);

    List<String> headers = [
      'S.No', 'Vehicle', 'Vehicle No', 'Driver', 'Bill No', 'Date', 
      'Party Name', 'Place', 'Phone No', 'Time', 'Diesel', 'Status', 'Details'
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    int rowIndex = 4;
    for (var row in reportRows) {
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(row['s_no'] as int);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(row['vehicle'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(row['vehicle_no'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(row['driver'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(row['bill_no'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(row['date'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(row['party_name'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = TextCellValue(row['place'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = TextCellValue(row['phone_no'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(row['time'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(row['diesel'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = TextCellValue(row['status'].toString());
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = TextCellValue(row['details'].toString());
      rowIndex++;
    }

    excel.delete('Sheet1');
    _autoFitColumns(excel);
    final bytes = excel.encode();
    if (bytes != null) {
      await _saveAndOpenExcel(bytes, 'Daily_Vehicle_Report_${DateTime.now().millisecondsSinceEpoch}');
    }
  }
}
