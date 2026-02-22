import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';

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
            const SnackBar(content: Text('Could not launch PayPal. Please check your internet connection.')),
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

  void _copyUpiId(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'drdhaval2785@okicici'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI ID copied to clipboard')),
    );
  }

  void _showUpiOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Donate via UPI',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy UPI ID'),
                subtitle: const Text('drdhaval2785@okicici\nCopy and pay via any UPI app of your choice'),
                isThreeLine: true,
                onTap: () {
                  Navigator.pop(context);
                  _copyUpiId(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
                title: const Text('Scan QR Code'),
                subtitle: const Text('Scan the QR code to pay'),
                onTap: () {
                  Navigator.pop(context);
                  _showQrCodeDialog(context);
                },
              ),
              const SizedBox(height: 16),
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
      drawer: const AppDrawer(),
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
                onPressed: () => _showUpiOptions(context),
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
