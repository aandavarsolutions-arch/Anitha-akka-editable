import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import 'print_settings_screen.dart';
import 'login_screen.dart';
import '../widgets/dev_branding_badge.dart';
import '../app_config.dart';

class SettingsBackupScreen extends StatefulWidget {
  const SettingsBackupScreen({super.key});

  @override
  State<SettingsBackupScreen> createState() => _SettingsBackupScreenState();
}

class _SettingsBackupScreenState extends State<SettingsBackupScreen> {
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final clientId = await provider.getSetting('google_client_id');
    final clientSecret = await provider.getSetting('google_client_secret');
    
    // 1. Show saved creds immediately
    if (mounted) {
      setState(() {
        _clientIdController.text = clientId ?? '';
        _clientSecretController.text = clientSecret ?? '';
        _isLoading = false; 
      });
    }

    // 2. Check connection in background
    final isOnline = await provider.checkConnection();
    if (mounted) {
      setState(() {
        _isConnected = isOnline;
      });
    }
  }

  Future<void> _connectDrive() async {
    print("UI: Connect Drive clicked");
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both Client ID and Secret')));
      return;
    }

    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.setSetting('google_client_id', clientId);
    await provider.setSetting('google_client_secret', clientSecret);
    
    // Trigger Authentication Flow
    try {
      print("UI: Calling provider.authenticateDrive");
      await provider.authenticateDrive(clientId, clientSecret);
      print("UI: Authentication returned");
       if (mounted) {
        setState(() => _isConnected = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication Successful!')));
      }
    } catch (e, stack) {
       print("UI: Authentication Error: $e");
       print(stack);
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10), // Longer duration to read
          action: SnackBarAction(label: 'Copy', onPressed: (){}), // Placeholder
        ));
      }
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: const Text('Backup & Recovery', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: const [DevBrandingBadge(textColor: Colors.black87)],
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          if (_isLoading) return const Center(child: CircularProgressIndicator());
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cloud Configuration
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  color: Colors.white,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text(
                        'Cloud Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        'Status: ${_isConnected ? "Connected" : "Disconnected"}',
                        style: TextStyle(
                           color: _isConnected ? Colors.green : Colors.red, 
                           fontWeight: FontWeight.bold, 
                           fontSize: 12
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: _clientIdController,
                                decoration: InputDecoration(
                                  labelText: 'Google Client ID',
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.account_circle_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _clientSecretController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Google Client Secret',
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.security),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (!AppConfig.isReadOnly)
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2C3E50), // Dark Blue
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.link),
                                    label: const Text('CONNECT GOOGLE DRIVE', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: _connectDrive,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // 2. Backup Management
                const Text('Backup Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!AppConfig.isReadOnly)
                        SizedBox(
                           width: 280, // Slightly wider
                          height: 45,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C3E50), // Dark Blue
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Backup to Google Drive'),
                            onPressed: () async {
                               setState(() => _isLoading = true);
                               // Perform Cloud Backup
                               final error = await data.cloudBackup();
                               
                               setState(() => _isLoading = false);
                               
                               if (mounted) {
                                 if (error == null) {
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup Uploaded to Google Drive Successfully!')));
                                 } else {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                 }
                               }
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      FutureBuilder<String?>(
                        future: data.getLastBackupTime(),
                        builder: (context, snapshot) {
                          return Text(
                            'Last Backup: ${snapshot.data ?? "Never"}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Restore Data
                const Text('Restore Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 8),
                const Text(
                  'Select a backup from Google Drive. WARNING: Replaces current data!',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                  if (!AppConfig.isReadOnly)
                   Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 250,
                        height: 45,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Restore from Drive'),
                          onPressed: () async {
                            // 1. Fetch List
                            setState(() => _isLoading = true);
                            final backups = await data.listCloudBackups();
                            setState(() => _isLoading = false);
                            
                            if (!mounted) return;
  
                            // 2. Show Dialog
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Select Backup to Restore'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 300,
                                  child: backups.isEmpty 
                                    ? const Center(child: Text("No backups found on Drive.")) 
                                    : ListView.builder(
                                        itemCount: backups.length,
                                        itemBuilder: (ctx, i) {
                                          final file = backups[i];
                                          return ListTile(
                                            leading: const Icon(Icons.description, color: Colors.blue),
                                            title: Text(file.name ?? 'Unknown'),
                                            subtitle: Text(file.createdTime?.toString() ?? ''),
                                            onTap: () async {
                                              Navigator.pop(ctx); // Close dialog
                                              // 3. Perform Restore
                                              setState(() => _isLoading = true);
                                              final error = await data.cloudRestore(file.id!);
                                              setState(() => _isLoading = false);
                                              
                                              if (mounted) {
                                                 if (error == null) {
                                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore Successful! App Data Updated.')));
                                                 } else {
                                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                                 }
                                              }
                                            },
                                          );
                                        },
                                      ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 4. Danger Zone
                const Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                const Text(
                  'Be careful! These actions cannot be undone.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (!AppConfig.isReadOnly)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Align(
                       alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 280,
                        height: 45,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Reset App Data (Delete All)'),
                          onPressed: () {
                             showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Reset App?'),
                                content: const Text('This will delete ALL data. This action cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () async {
                                      try {
                                        Navigator.pop(context); // Close dialog first
                                        await data.resetApp();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App has been reset')));
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reset: $e'), backgroundColor: Colors.red));
                                        }
                                      }
                                    },
                                    child: const Text('RESET'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
                
                // Hardware Link (Preserved for functionality)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrintSettingsScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Row(
                      children: [
                         Icon(Icons.print, color: Colors.blueGrey),
                         SizedBox(width: 12),
                         Text('Printer Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                         Spacer(),
                         Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

          const SizedBox(height: 16),
          // Logout Option
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => const LoginScreen())
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                children: [
                   Icon(Icons.logout, color: Colors.redAccent),
                   SizedBox(width: 12),
                   Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                   Spacer(),
                   Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
        },
      ),
    );
  }
}
