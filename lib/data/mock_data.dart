import '../widgets/status_chip.dart';

class MockData {
  static const List<Map<String, dynamic>> recentTransactions = [
    {
      'title': 'Cement Purchase (50 bags)',
      'subtitle': 'Chennai Site - Material',
      'amount': '₹18,500',
      'date': 'Today',
      'status': StatusType.paid,
      'isExpense': true,
    },
    {
      'title': 'Advance from Mr. Rajesh',
      'subtitle': 'Villa Project - Client',
      'amount': '₹50,000',
      'date': 'Today',
      'status': StatusType.paid,
      'isExpense': false,
    },
    {
      'title': 'Labour Payment (Weekly)',
      'subtitle': 'Chennai Site - Labour',
      'amount': '₹12,000',
      'date': 'Yesterday',
      'status': StatusType.paid,
      'isExpense': true,
    },
    {
      'title': 'Steel Delivery',
      'subtitle': 'Supplier: XYZ Steels',
      'amount': '₹1,20,000',
      'date': '12 Dec',
      'status': StatusType.pending,
      'isExpense': true,
    },
    {
      'title': 'JCB Rental (3 days)',
      'subtitle': 'Kovai Site - Vehicle',
      'amount': '₹15,000',
      'date': '10 Dec',
      'status': StatusType.partial,
      'isExpense': true,
    },
  ];

  static const List<Map<String, dynamic>> bills = [
    {
      'id': 'BILL-2023-001',
      'site': 'Chennai Site - Block A',
      'date': '12 Dec 2023',
      'amount': '₹1,50,000',
      'status': StatusType.paid,
    },
    {
      'id': 'BILL-2023-002',
      'site': 'Kovai Villa Project',
      'date': '10 Dec 2023',
      'amount': '₹4,20,500',
      'status': StatusType.partial,
    },
    {
      'id': 'EST-2023-089',
      'site': 'Madurai Commercial Complex',
      'date': '08 Dec 2023',
      'amount': '₹85,000',
      'status': StatusType.pending,
    },
    {
      'id': 'BILL-2023-003',
      'site': 'Chennai Site - Block B',
      'date': '05 Dec 2023',
      'amount': '₹2,10,000',
      'status': StatusType.paid,
    },
  ];

  static const List<Map<String, dynamic>> vehicles = [
    {
      'number': 'TN 33 AA 1234',
      'type': 'Ashok Leyland Lorry',
      'isOwn': true,
      'total': '₹50,000',
      'paid': '₹35,000',
      'balance': '₹15,000',
      'status': StatusType.partial,
    },
    {
      'number': 'TN 66 Z 9876',
      'type': 'JCB Excavator',
      'isOwn': true,
      'total': '₹1,20,000',
      'paid': '₹1,20,000',
      'balance': '₹0',
      'status': StatusType.paid,
    },
    {
      'number': 'TN 45 X 5555',
      'type': 'Rental Tractor',
      'isOwn': false,
      'total': '₹12,000',
      'paid': '₹0',
      'balance': '₹12,000',
      'status': StatusType.pending,
    },
  ];

  static const List<Map<String, dynamic>> expenses = [
    {
      'title': 'Cement (50 Bags)',
      'category': 'Material',
      'amount': '₹18,500',
      'date': 'Today',
    },
    {
      'title': 'Mason Kumar (Weekly)',
      'category': 'Labour',
      'amount': '₹8,500',
      'date': 'Today',
    },
    {
      'title': 'JCB Rental',
      'category': 'Vehicle',
      'amount': '₹4,500',
      'date': 'Yesterday',
    },
    {
      'title': 'Tea & Snacks',
      'category': 'Other',
      'amount': '₹350',
      'date': 'Yesterday',
    },
    {
      'title': 'Sand Load',
      'category': 'Material',
      'amount': '₹12,000',
      'date': '10 Dec',
    },
  ];

  static const List<Map<String, dynamic>> labour = [
    {
      'name': 'Ramesh (Mason)',
      'site': 'Chennai Site',
      'type': 'Daily',
      'advance': '₹5,000',
      'balance': '₹2,500',
    },
    {
      'name': 'Suresh (Helper)',
      'site': 'Kovai Site',
      'type': 'Weekly',
      'advance': '₹1,000',
      'balance': '₹4,000',
    },
    {
      'name': 'Team A (Contract)',
      'site': 'Project Alpha',
      'type': 'Contract',
      'advance': '₹50,000',
      'balance': '₹1,50,000',
    },
  ];

  static const List<Map<String, dynamic>> suppliers = [
    {
      'name': 'ABC Steels Ltd',
      'material': 'Steel',
      'total': '₹5,00,000',
      'paid': '₹3,50,000',
      'balance': '₹1,50,000',
    },
    {
      'name': 'Maha Cement Store',
      'material': 'Cement',
      'total': '₹2,20,000',
      'paid': '₹2,20,000',
      'balance': '₹0',
    },
    {
      'name': 'Kovai Blue Metal',
      'material': 'Aggregate',
      'total': '₹85,000',
      'paid': '₹40,000',
      'balance': '₹45,000',
    },
  ];

  static const List<Map<String, dynamic>> drivers = [
    {
      'name': 'Manikandan',
      'vehicle': 'Lorry TN 33 AA...',
      'type': 'Trip',
      'earnings': '₹4,500',
      'status': StatusType.pending,
    },
    {
      'name': 'Sekar',
      'vehicle': 'JCB TN 66 Z...',
      'type': 'Daily',
      'earnings': '₹850',
      'status': StatusType.paid,
    },
    {
      'name': 'Ravi',
      'vehicle': 'Tractor',
      'type': 'Monthly',
      'earnings': '₹18,000',
      'status': StatusType.partial,
    },
  ];

  static const List<Map<String, dynamic>> siteIncome = [
    {
      'site': 'Chennai Villa Project',
      'client': 'Mr. Sundar',
      'received': '₹25,00,000',
      'pending': '₹5,00,000',
      'profit': '+12%',
      'isProfit': true,
    },
    {
      'site': 'Kovai Warehouse',
      'client': 'XYZ Logistics',
      'received': '₹40,00,000',
      'pending': '₹10,00,000',
      'profit': '-2%',
      'isProfit': false,
    },
  ];
}
