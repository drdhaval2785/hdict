import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launchUrl(String urlString, BuildContext context) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch app. Please try the QR code.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _donateUpi(BuildContext context) async {
    const query = 'pa=drdhaval2785@okicici&pn=Dhaval%20Patel&tr=DONATION_PAY&tn=Donation%20to%20hdict&am=100.00&cu=INR';
    
    if (io.Platform.isIOS) {
      // On iOS, we must show a list of specific apps because upi:// only opens one default app.
      _showUpiAppPicker(context, query);
    } else {
      // On Android, upi:// triggers the system intent chooser, which is preferred.
      final urlString = 'upi://pay?$query';
      final Uri url = Uri.parse(urlString);

      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            _showQrCodeDialog(context);
          }
        }
      } catch (e) {
        if (context.mounted) {
          _showQrCodeDialog(context);
        }
      }
    }
  }

  void _showUpiAppPicker(BuildContext context, String query) async {
    final Map<String, String> apps = {
      'Google Pay': 'gpay://upi/pay',
      'PhonePe': 'phonepe://pay',
      'Paytm': 'paytmmp://pay',
      'BHIM': 'bhim://pay',
      'Amazon Pay': 'com.amazon.mobile.shopping://pay',
      'WhatsApp': 'whatsapp://pay',
    };

    final List<MapEntry<String, String>> installedApps = [];
    for (var entry in apps.entries) {
      if (await canLaunchUrl(Uri.parse('${entry.value.split('://')[0]}://'))) {
        installedApps.add(entry);
      }
    }

    if (!context.mounted) return;

    if (installedApps.isEmpty) {
      _showQrCodeDialog(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select UPI App',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...installedApps.map((app) => ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(app.key),
                onTap: () {
                  Navigator.pop(context);
                  _launchUrl('${app.value}?$query', context);
                },
              )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Show QR Code (Fallback)'),
                onTap: () {
                  Navigator.pop(context);
                  _showQrCodeDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan to Pay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/upi_qr.png',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 16),
            const Text(
              'UPI ID: drdhaval2785@okicici',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan this QR code using any UPI app to donate.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _donatePaypal(BuildContext context) {
    const paypalUrl = 'https://paypal.me/drdhaval2785/10USD';
    _launchUrl(paypalUrl, context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Us'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            Text(
              'Keep hdict Free & Libre',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'hdict is a free and open-source (Libre) project dedicated to providing high-quality dictionary tools without advertisements or data tracking. Our mission is to keep knowledge accessible to everyone, forever.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your contributions help cover hosting costs, development tools, and allow us to dedicate more time to improving the app and adding new features.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            Text(
              'Choose your preferred method:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _donateUpi(context),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Donate via UPI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showQrCodeDialog(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Show QR Code (Fallback)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _donatePaypal(context),
                icon: const Icon(Icons.payment),
                label: const Text('Donate via PayPal'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Thank you for your support!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Every contribution, no matter how small, makes a huge difference.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
