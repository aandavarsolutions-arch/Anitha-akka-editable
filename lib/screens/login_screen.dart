import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../theme.dart';
import '../data/data_provider.dart';
import 'main_navigation_screen.dart';
import 'system_diagnostics_screen.dart';
import 'gst_dashboard_screen.dart'; // Import this
import '../widgets/dev_branding_badge.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50), // Dark Blue Background
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        FutureBuilder<Map<String, String?>>(
                          future: _getBusinessInfo(context),
                          builder: (context, snapshot) {
                            final logoPath = snapshot.data?['logo'];
                            final businessName = snapshot.data?['name'];

                            return Column(
                              children: [
                                if (logoPath != null && File(logoPath).existsSync())
                                  Image.file(File(logoPath), height: 80, errorBuilder: (_,__,___) => Image.asset('assets/logo.png', height: 80))
                                else
                                  Image.asset('assets/logo.png', height: 80),
                                
                                const SizedBox(height: 16),
                                
                                if (businessName != null && businessName.isNotEmpty)
                                  Text(
                                    businessName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: JarvisTheme.primary, letterSpacing: 1.2),
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 32),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                          ),
                        KeyboardListener(
                          focusNode: FocusNode(), // Simple focus node for listener
                          onKeyEvent: (event) {
                             if (event is KeyDownEvent) {
                               print("DEBUG KEY: ${event.logicalKey.debugName} (ID: ${event.logicalKey.keyId})");
                             }
                          },
                          child: TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: JarvisTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 16,
            right: 16,
            child: DevBrandingBadge(),
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. ANDAVAR (Master) Logic
    if (username == 'Aandavar' && password == 'srikka') {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Aandavar System Login Success!'), backgroundColor: Colors.green),
         );
         Navigator.pushReplacement(
           context, 
           MaterialPageRoute(builder: (_) => const SystemDiagnosticsScreen())
         );
      }
      return;
    }

    // 2. GST Login Logic (Credential Based)
    if (username == 'GST' && password == '1234') { 
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GST Login Success!'), backgroundColor: Colors.blue),
          );
          // Navigate to GST Dashboard or Main Screen with GST context
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const GstDashboardScreen()),
          );
       }
       return;
    }

    // 3. Standard Logic
    final success = await Provider.of<DataProvider>(context, listen: false).login(username, password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Invalid Credentials');
      }
    }
  }
  Future<Map<String, String?>> _getBusinessInfo(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final name = await provider.getSetting('business_name');
    final logoPath = await provider.getLogoPath();
    return {'name': name, 'logo': logoPath};
  }
}
