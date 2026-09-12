import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../data/data_provider.dart';

class DevBrandingBadge extends StatelessWidget {
  final Color textColor;
  const DevBrandingBadge({super.key, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _getDevInfo(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final name = snapshot.data?['name'];
        final logo = snapshot.data?['logo'];

        if (name == null && logo == null) return const SizedBox.shrink();

        final contact = snapshot.data?['contact'];
        final email = snapshot.data?['email'];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ALERT BELL ICON (Insurance, FC, PUC, License Expiries)
            Consumer<DataProvider>(
              builder: (context, data, _) {
                final alerts = data.expiryAlerts;
                final int alertCount = alerts.length;
                final bool hasExpired = alerts.any((a) => a['is_expired'] == true);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        alertCount > 0 ? Icons.notifications_active : Icons.notifications_none,
                        color: alertCount > 0 ? (hasExpired ? Colors.redAccent : Colors.amberAccent) : textColor.withValues(alpha: 0.7),
                        size: 22,
                      ),
                      tooltip: 'Document Expiry Alerts ($alertCount)',
                      onPressed: () => _showExpiryAlertsDialog(context, alerts),
                    ),
                    if (alertCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: hasExpired ? Colors.red : Colors.orange[800],
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$alertCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 4),

            // BRANDING BADGE (Aandavar Solutions)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    contentPadding: const EdgeInsets.all(24),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (logo != null && File(logo).existsSync())
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blueGrey, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: ClipOval(
                              child: Image.file(
                                File(logo),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else 
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blueGrey, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (name != null)
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (contact != null && contact.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.phone, color: Colors.blue),
                            title: Text(contact),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (email != null && email.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.email, color: Colors.redAccent),
                            title: Text(email),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
                    ],
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (name != null)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15, 
                          color: textColor, // Dynamic color
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
                        ),
                      ),
                    if (name != null && logo != null) const SizedBox(width: 10),
                    if (logo != null && File(logo).existsSync())
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: ClipOval(
                          child: Image.file(
                            File(logo),
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: 36, height: 36, fit: BoxFit.cover),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/logo.png', width: 36, height: 36, fit: BoxFit.cover),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showExpiryAlertsDialog(BuildContext context, List<Map<String, dynamic>> alerts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              alerts.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: alerts.isNotEmpty ? Colors.orange[800] : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('DOCUMENT EXPIRY ALERTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: alerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, color: Colors.green, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'All Documents Valid!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No vehicle (Insurance/FC/PUC) or driver license expiries within the next 30 days.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = alerts[idx];
                    final bool isExpired = item['is_expired'] == true;
                    final int daysLeft = item['days_left'] as int;

                    String subtitleStr;
                    if (isExpired) {
                      subtitleStr = 'EXPIRED ${daysLeft.abs()} day${daysLeft.abs() == 1 ? "" : "s"} ago • ${item['date']}';
                    } else if (daysLeft == 0) {
                      subtitleStr = 'EXPIRING TODAY! • ${item['date']}';
                    } else {
                      subtitleStr = 'Expiring in $daysLeft day${daysLeft == 1 ? "" : "s"} • ${item['date']}';
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: isExpired ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        child: Icon(
                          item['category'] == 'Driver' ? Icons.badge : Icons.directions_car,
                          color: isExpired ? Colors.red : Colors.orange[800],
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${item['title']} - ${item['doc_type']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        subtitleStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isExpired ? Colors.red : Colors.orange[900],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red : Colors.orange[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isExpired ? 'EXPIRED' : 'DUE SOON',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String?>> _getDevInfo(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final name = await provider.getSetting('dev_name');
    final logo = await provider.getSetting('dev_logo_path');
    final contact = await provider.getSetting('dev_contact');
    final email = await provider.getSetting('dev_email');
    return {'name': name, 'logo': logo, 'contact': contact, 'email': email};
  }
}
