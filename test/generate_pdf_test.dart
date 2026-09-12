import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_customer2/services/pdf_service.dart';
import 'package:jarvis_customer2/services/excel_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate Customer Statement PDF test', () async {
    Uint8List? headerImageBytes;
    final headerFile = File('assets/customer_header.png');
    print('Header file exists in test: ${headerFile.existsSync()}, absolute path: ${headerFile.absolute.path}');
    final bytes = await PdfService.generateCustomerAccountStatementBytes(
      customerName: 'Prabu1',
      customerAddress: 'palani',
      headerImagePath: headerFile.absolute.path,
      dataRows: List.generate(50, (i) => [
        '${i + 1}',
        '${(i % 30) + 1}.08.26',
        'Lorry(TN${1000 + i})',
        i % 2 == 0 ? 'Hour' : 'Day',
        '${(i % 5) + 1}',
        '${(i + 1) * 500}',
        '${(i % 3) * 100}',
        i % 3 == 0 ? 'Gravel' : (i % 3 == 1 ? 'M-Sand' : 'Dust'),
        '${(i + 1) * 600}',
      ]),
      totals: {
        'Total Amount': 'Rs. 250000',
        'Paid Amount': 'Rs. 50000',
        'Balance': 'Rs. 200000',
      },
    );

    final file = File('C:/Users/sarav/AppData/Local/Temp/Prabu1_Statement_test.pdf');
    await file.writeAsBytes(bytes);
    print('Generated test PDF at ${file.path}');
  });

  test('Generate Customer Statement Excel test', () async {
    await ExcelService.generateCustomerAccountStatementExcel(
      customerName: 'Prabu1',
      customerAddress: 'palani',
      dataRows: List.generate(10, (i) => [
        '${i + 1}',
        '${i + 1}.08.26',
        'Lorry(TN${1000 + i})',
        'Hour',
        '1',
        '1000',
        '100',
        'Gravel',
        '1100',
      ]),
      totals: {
        'Total Amount': 'Rs. 11000',
        'Paid Amount': 'Rs. 5000',
        'Balance': 'Rs. 6000',
      },
    );
    print('Generated test Excel successfully');
  });
}
