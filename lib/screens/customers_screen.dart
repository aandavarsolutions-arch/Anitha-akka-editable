import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import '../widgets/dev_branding_badge.dart';
import 'vehicle_payments_screen.dart';
import 'customer_ledger_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../app_config.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String _sortBy = 'address'; // Default sort by Address / Town
  String _balanceFilter = 'all'; // 'all', 'pending', 'zero'
  String _addressFilter = 'all'; // 'all' or specific town string

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredAndSortedCustomers(List<Map<String, dynamic>> rawList, DataProvider data) {
    var list = List<Map<String, dynamic>>.from(rawList);

    // 1. Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final addr = (c['address'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || addr.contains(_searchQuery);
      }).toList();
    }

    // 2. Balance Filter
    if (_balanceFilter == 'pending') {
      list = list.where((c) => data.parseAmount(c['balance']) > 0).toList();
    } else if (_balanceFilter == 'zero') {
      list = list.where((c) => data.parseAmount(c['balance']) <= 0).toList();
    }

    // 3. Address Filter
    if (_addressFilter != 'all') {
      list = list.where((c) {
        final addr = (c['address'] ?? '').toString().trim().toLowerCase();
        return addr == _addressFilter.toLowerCase();
      }).toList();
    }

    // 4. Sorting
    return _getSortedCustomers(list, data);
  }

  List<Map<String, dynamic>> _getSortedCustomers(List<Map<String, dynamic>> list, DataProvider data) {
    final sortedList = List<Map<String, dynamic>>.from(list);
    if (_sortBy == 'address') {
      sortedList.sort((a, b) {
        final addrA = (a['address'] ?? '').toString().trim().toLowerCase();
        final addrB = (b['address'] ?? '').toString().trim().toLowerCase();
        if (addrA.isEmpty && addrB.isNotEmpty) return 1;
        if (addrA.isNotEmpty && addrB.isEmpty) return -1;
        int cmp = addrA.compareTo(addrB);
        if (cmp != 0) return cmp;
        final nameA = (a['name'] ?? '').toString().trim().toLowerCase();
        final nameB = (b['name'] ?? '').toString().trim().toLowerCase();
        return nameA.compareTo(nameB);
      });
    } else if (_sortBy == 'name') {
      sortedList.sort((a, b) {
        final nameA = (a['name'] ?? '').toString().trim().toLowerCase();
        final nameB = (b['name'] ?? '').toString().trim().toLowerCase();
        return nameA.compareTo(nameB);
      });
    } else if (_sortBy == 'balance') {
      sortedList.sort((a, b) {
        final balA = data.parseAmount(a['balance']);
        final balB = data.parseAmount(b['balance']);
        return balB.compareTo(balA);
      });
    }
    return sortedList;
  }

  void _showFilterDialog(BuildContext context) {
    final data = Provider.of<DataProvider>(context, listen: false);
    final Set<String> uniqueAddresses = {};
    for (var c in data.customers) {
      final addr = (c['address'] ?? '').toString().trim();
      if (addr.isNotEmpty) uniqueAddresses.add(addr);
    }
    final sortedAddresses = uniqueAddresses.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final List<String> autocompleteOptions = ['All Addresses / Towns', ...sortedAddresses];

    String tempBalanceFilter = _balanceFilter;
    final addressTextController = TextEditingController(
      text: _addressFilter == 'all' ? '' : _addressFilter
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.filter_alt, color: JarvisTheme.secondary),
                  SizedBox(width: 8),
                  Text('Filter Customers', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Balance Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    RadioListTile<String>(
                      title: const Text('All Customers'),
                      value: 'all',
                      groupValue: tempBalanceFilter,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => tempBalanceFilter = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Pending Balance Only (> ₹0)'),
                      value: 'pending',
                      groupValue: tempBalanceFilter,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => tempBalanceFilter = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Zero / Settled Balance (₹0)'),
                      value: 'zero',
                      groupValue: tempBalanceFilter,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => tempBalanceFilter = val!),
                    ),
                    const Divider(height: 24),
                    const Text('Address / Town Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: addressTextController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return sortedAddresses;
                        }
                        return sortedAddresses.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        addressTextController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (val) {
                            addressTextController.text = val;
                          },
                          decoration: InputDecoration(
                            hintText: 'Type or select Town (e.g. Palani)...',
                            prefixIcon: const Icon(Icons.location_city, size: 20),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            suffixIcon: autocompleteOptions.isNotEmpty
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down),
                                    onSelected: (String value) {
                                      final selectedText = value == 'All Addresses / Towns' ? '' : value;
                                      controller.text = selectedText;
                                      addressTextController.text = selectedText;
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return autocompleteOptions.map((String choice) {
                                        return PopupMenuItem<String>(
                                          value: choice,
                                          child: Text(choice),
                                        );
                                      }).toList();
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempBalanceFilter = 'all';
                      addressTextController.clear();
                    });
                  },
                  child: const Text('RESET', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JarvisTheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final typedTown = addressTextController.text.trim();
                    setState(() {
                      _balanceFilter = tempBalanceFilter;
                      if (typedTown.isEmpty || typedTown == 'All Addresses / Towns') {
                        _addressFilter = 'all';
                      } else {
                        _addressFilter = typedTown;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('APPLY'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilter = _balanceFilter != 'all' || _addressFilter != 'all';

    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search customers...',
                  border: InputBorder.none,
                  filled: false,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : const Text('MANAGE CUSTOMERS'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.filter_alt,
                  color: hasActiveFilter ? Colors.amberAccent : Colors.white,
                ),
                tooltip: 'Filter Customers',
                onPressed: () => _showFilterDialog(context),
              ),
              if (hasActiveFilter)
                Positioned(
                  right: 8,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Customers',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'address',
                child: Row(
                  children: [
                    Icon(Icons.location_city, size: 18, color: _sortBy == 'address' ? JarvisTheme.secondary : Colors.grey),
                    const SizedBox(width: 8),
                    Text('Sort by Address / Town', style: TextStyle(fontWeight: _sortBy == 'address' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18, color: _sortBy == 'name' ? JarvisTheme.secondary : Colors.grey),
                    const SizedBox(width: 8),
                    Text('Sort by Name', style: TextStyle(fontWeight: _sortBy == 'name' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'balance',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 18, color: _sortBy == 'balance' ? JarvisTheme.secondary : Colors.grey),
                    const SizedBox(width: 8),
                    Text('Sort by Balance (High to Low)', style: TextStyle(fontWeight: _sortBy == 'balance' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          Consumer<DataProvider>(
            builder: (context, data, _) => IconButton(
              tooltip: 'Print Customer List',
              icon: const Icon(Icons.print),
              onPressed: () => _printCustomerList(context, data),
            ),
          ),
          Consumer<DataProvider>(
            builder: (context, data, _) => IconButton(
              tooltip: 'Export Excel List',
              icon: const Icon(Icons.grid_on),
              onPressed: () => _exportCustomerListExcel(context, data),
            ),
          ),
          const DevBrandingBadge(),
        ],
      ),
      floatingActionButton: AppConfig.isReadOnly ? null : FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          final customers = _getFilteredAndSortedCustomers(data.customers, data);

          return Column(
            children: [
              if (hasActiveFilter)
                Container(
                  color: JarvisTheme.secondary.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 16, color: JarvisTheme.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_balanceFilter == 'pending')
                              Chip(
                                label: const Text('Pending > ₹0', style: TextStyle(fontSize: 11)),
                                onDeleted: () => setState(() => _balanceFilter = 'all'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            if (_balanceFilter == 'zero')
                              Chip(
                                label: const Text('Zero Balance (₹0)', style: TextStyle(fontSize: 11)),
                                onDeleted: () => setState(() => _balanceFilter = 'all'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            if (_addressFilter != 'all')
                              Chip(
                                label: Text('Town: $_addressFilter', style: const TextStyle(fontSize: 11)),
                                onDeleted: () => setState(() => _addressFilter = 'all'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _balanceFilter = 'all';
                            _addressFilter = 'all';
                          });
                        },
                        child: const Text('CLEAR ALL', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              Expanded(
                child: customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              hasActiveFilter || _searchQuery.isNotEmpty
                                  ? 'No customers match selected filters.'
                                  : 'No customers found. Add one to start.',
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          final balance = data.parseAmount(customer['balance']);
                          
                          return Card(
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => CustomerLedgerScreen(customerName: customer['name'])
                                  )
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: JarvisTheme.secondary.withValues(alpha: 0.1),
                                child: const Icon(Icons.person, color: JarvisTheme.secondary),
                              ),
                              title: Text(
                                customer['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (customer['address'] != null && customer['address'].toString().trim().isNotEmpty)
                                    Text('Address: ${customer['address']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)),
                                  if (customer['phone'] != null && customer['phone'].isNotEmpty)
                                    Text(customer['phone'], style: const TextStyle(fontSize: 12)),
                                  Text(
                                    'Balance: ₹${balance.toInt()}',
                                    style: TextStyle(
                                      color: balance > 0 ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: AppConfig.isReadOnly ? null : PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showAddCustomerDialog(context, customer: customer);
                                  } else if (value == 'ledger') {
                                     Navigator.push(
                                      context, 
                                      MaterialPageRoute(
                                        builder: (_) => CustomerLedgerScreen(customerName: customer['name'])
                                      )
                                    );
                                  } else if (value == 'vehicles') {
                                    Navigator.push(
                                      context, 
                                      MaterialPageRoute(
                                        builder: (_) => VehiclePaymentsScreen(isOwn: true, customerName: customer['name'])
                                      )
                                    );
                                  } else if (value == 'pdf') {
                                    _generateCustomerPdf(context, customer['name']);
                                  } else if (value == 'excel') {
                                    _generateCustomerExcel(context, customer['name']);
                                  } else if (value == 'delete') {
                                    final cName = customer['name'] ?? 'Customer';
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        content: Text('Are you sure you want to delete customer "$cName"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('CANCEL'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              data.deleteCustomer(customer['id']);
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Customer "$cName" deleted')),
                                              );
                                            },
                                            child: const Text('DELETE'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'ledger', child: Text('Ledger (Bill/Pay)')),
                                  const PopupMenuItem(value: 'vehicles', child: Text('Vehicle List')),
                                  const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.grey, size: 20), SizedBox(width: 8), Text('Save PDF Invoice')])),
                                  const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.grid_on, color: Colors.grey, size: 20), SizedBox(width: 8), Text('Save Excel Invoice')])),
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, {Map<String, dynamic>? customer}) {
    final nameController = TextEditingController(text: customer?['name'] ?? '');
    final phoneController = TextEditingController(text: customer?['phone'] ?? '');
    final addressController = TextEditingController(text: customer?['address'] ?? '');
    final focusNodeAddress = FocusNode();

    showDialog(
      context: context,
      builder: (context) => Consumer<DataProvider>(
        builder: (context, data, child) {
          final Set<String> uniquePlaces = {};
          for (var c in data.customers) {
            final addr = (c['address'] ?? '').toString().trim();
            if (addr.isNotEmpty) uniquePlaces.add(addr);
          }
          for (var s in data.allSites) {
            final sName = s.trim();
            if (sName.isNotEmpty && sName != 'All Sites' && sName != 'General') uniquePlaces.add(sName);
          }
          final List<String> options = uniquePlaces.toList()..sort();

          return AlertDialog(
            title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Customer Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    textEditingController: addressController,
                    focusNode: focusNodeAddress,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') return options;
                      return options.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      addressController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Address / Town (Optional)',
                          hintText: 'e.g. Salem, Trichy',
                          suffixIcon: options.isNotEmpty
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.arrow_drop_down),
                                  onSelected: (String value) {
                                    controller.text = value;
                                    addressController.text = value;
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return options.map((String choice) {
                                      return PopupMenuItem<String>(
                                        value: choice,
                                        child: Text(choice),
                                      );
                                    }).toList();
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  final address = addressController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a customer name'))
                    );
                    return;
                  }

                  // Duplicate Check: Phone if provided, Name if phone is empty
                  if (phone.isNotEmpty) {
                    final existing = data.customers.firstWhere(
                      (c) => (c['phone'] ?? '').toString().replaceAll(' ', '') == phone.replaceAll(' ', '') &&
                             (customer == null || c['id'].toString() != customer['id'].toString()),
                      orElse: () => {},
                    );

                    if (existing.isNotEmpty) {
                      final existingName = existing['name'] ?? 'Customer';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Customer with phone "$phone" ALREADY EXISTS! ($existingName)'),
                          backgroundColor: Colors.red[800],
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                  } else {
                    final existing = data.customers.firstWhere(
                      (c) => (c['name'] ?? '').toString().toLowerCase().trim() == name.toLowerCase().trim() &&
                             (customer == null || c['id'].toString() != customer['id'].toString()),
                      orElse: () => {},
                    );

                    if (existing.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Customer with name "$name" ALREADY EXISTS!'),
                          backgroundColor: Colors.red[800],
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                  }

                  final customerData = {
                    'name': name,
                    'phone': phone,
                    'address': address,
                  };
                  
                  if (customer != null) {
                    data.updateCustomer(customer['id'], customerData);
                  } else {
                    data.addCustomer(customerData);
                  }
                  Navigator.pop(context);
                },
                child: const Text('SAVE'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printCustomerList(BuildContext context, DataProvider data) async {
    final customers = _getFilteredAndSortedCustomers(data.customers, data);

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers to print')),
      );
      return;
    }
    final businessName = await data.getSetting('business_name') ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF...')),
    );
    await PdfService.generateCustomerListPdf(
      customers: customers,
      businessName: businessName,
      parseAmount: data.parseAmount,
      preserveSort: true,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer list PDF opened!')),
      );
    }
  }

  Future<void> _generateCustomerPdf(BuildContext context, String customerName) async {
    final data = Provider.of<DataProvider>(context, listen: false);
    final vehicles = data.allVehicles.where((v) => 
      v['customer']?.toString().toLowerCase().trim() == customerName.toLowerCase().trim() && 
      data.parseAmount(v['balance']) > 0
    ).toList();

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending bills for this customer')));
      return;
    }

    double total = 0;
    for (var v in vehicles) {
       total += data.parseAmount(v['balance']);
    }
    
    vehicles.sort((a, b) {
       try {
         return DateFormat('dd MMM yyyy').parse(b['date']).compareTo(DateFormat('dd MMM yyyy').parse(a['date']));
       } catch (_) { return 0; }
    });

    // Prepare table data
    final List<List<String>> rows = [];
    
    for (var item in vehicles) {
       String amount = item['balance'] ?? '0'; // Use balance for pending report
       // Ensure currency symbol is clean
       amount = amount.replaceAll('₹', 'Rs. ').replaceAll('Rs.', 'Rs. '); 
       // Note: item['balance'] might be '₹5000'. parseAmount handles string parsing for math, 
       // but here we just want display string. 
       // Wait, item['balance'] comes from DB as string (e.g. "₹5000").
       // So replaceAll is correct.
       
       String desc = item['type'] != null ? '${item['type']} - ${item['number']}' : (item['number'] ?? 'Vehicle');
       String rateInfo = '';
       String qty = '';

       // 1. Vehicle Info
       if (item['duration'] != null && item['rate'] != null) {
           final unit = item['rate_type'] == 'Trip' ? 'Trips' : (item['rate_type'] ?? 'Unit');
           rateInfo = 'Rs. ${item['rate']}/$unit';
           qty = '${item['duration']} $unit';
       }

       // 2. Material Info
       if (item['material_name'] != null && item['material_name'].toString().isNotEmpty) {
           desc += '\n+ ${item['material_name']}'; // e.g. "Sand"
           
           // Material Rate Calculation
           double matAmount = data.parseAmount(item['material_amount']);
           double matQty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
           if (matQty > 0 && matAmount > 0) {
                double matRate = matAmount / matQty;
                if (rateInfo.isNotEmpty) rateInfo += '\n';
                rateInfo += 'Rs. ${matRate.toStringAsFixed(0)}/${item['unit'] ?? 'Unit'}';
           } else if (rateInfo.isNotEmpty) {
               rateInfo += '\n-'; 
           }
           
           // Append Qty
           if (qty.isNotEmpty) qty += '\n'; 
           qty += '${item['quantity']} ${item['unit'] ?? ''}';
       }

       rows.add([
           item['date'],
           desc,
           rateInfo,
           qty,
           amount
       ]);
    }

    // Fetch Business Settings
    final businessName = await data.getSetting('business_name');
    final logoPath = await data.getLogoPath();

    // Use PdfService
    await PdfService.generateLedgerPdf(
      title: 'Customer Invoice - $customerName',
      subTitle: 'Pending Bills Statement',
      headers: ['Date', 'Description', 'Rate', 'Qty', 'Amount'],
      data: rows,
      totals: {'Total Pending': 'Rs. ${total.toStringAsFixed(0)}'},
      businessName: businessName,
      logoPath: logoPath,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
     
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice Generated Successfully')));
  }

  Future<void> _exportCustomerListExcel(BuildContext context, DataProvider data) async {
    final customers = _getFilteredAndSortedCustomers(data.customers, data);

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers to export')),
      );
      return;
    }
    final businessName = await data.getSetting('business_name') ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Excel...')),
    );
    await ExcelService.generateCustomerListExcel(
      customers: customers,
      businessName: businessName,
      parseAmount: data.parseAmount,
      preserveSort: true,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer list Excel opened!')),
      );
    }
  }

  Future<void> _generateCustomerExcel(BuildContext context, String customerName) async {
    final data = Provider.of<DataProvider>(context, listen: false);
    final vehicles = data.allVehicles.where((v) => 
      v['customer']?.toString().toLowerCase().trim() == customerName.toLowerCase().trim() && 
      data.parseAmount(v['balance']) > 0
    ).toList();

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending bills for this customer')));
      return;
    }

    final List<List<String>> rows = [];
    double total = 0;

    for (var item in vehicles) {
       double balance = data.parseAmount(item['balance']);
       total += balance;

       String desc = '${item['vehicle_no']}\n';
       desc += item['material_name']?.toString().isNotEmpty == true ? '${item['material_name']}' : 'Rent';
       if (item['remarks']?.toString().isNotEmpty == true) {
         desc += ' (${item['remarks']})';
       }

       String rateInfo = '';
       String qty = '';
       String amount = 'Rs. ${balance.toStringAsFixed(0)}';

       double matAmount = data.parseAmount(item['material_amount']);
       if (matAmount > 0) {
            double matQty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
            if (matQty > 0 && matAmount > 0) {
                 double matRate = matAmount / matQty;
                 rateInfo = 'Rs. ${matRate.toStringAsFixed(0)}/${item['unit'] ?? 'Unit'}';
            }
            qty = '${item['quantity']} ${item['unit'] ?? ''}';
       }

       rows.add([
           item['date'],
           desc,
           rateInfo,
           qty,
           amount
       ]);
    }

    final businessName = await data.getSetting('business_name');

    await ExcelService.generateLedgerExcel(
      title: 'Customer Invoice - $customerName',
      subTitle: 'Pending Bills Statement',
      headers: ['Date', 'Description', 'Rate', 'Qty', 'Amount'],
      data: rows,
      totals: {'Total Pending': 'Rs. ${total.toStringAsFixed(0)}'},
      businessName: businessName,
    );
     
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Invoice Generated Successfully')));
  }
}
