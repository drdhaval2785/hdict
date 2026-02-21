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
            SnackBar(content: Text('Could not launch $urlString')),
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

  void _showUpiOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _UpiOptionsList(
          onAppSelected: (url) => _launchUrl(url, context),
          onShowQrCode: () => _showQrCodeDialog(context),
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
    const paypalUrl = 'https://paypal.me/drdhaval2785';
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

class _UpiOptionsList extends StatelessWidget {
  final Function(String) onAppSelected;
  final VoidCallback onShowQrCode;

  const _UpiOptionsList({
    required this.onAppSelected,
    required this.onShowQrCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const upiParams = 'pay?pa=drdhaval2785@okicici&pn=Dhaval%20Patel&cu=INR';
    
    final apps = [
      {'name': 'BHIM', 'icon': Icons.account_balance, 'url': 'upi://$upiParams'},
      {'name': 'Google Pay', 'icon': Icons.payment, 'url': 'tez://$upiParams'},
      {'name': 'Paytm', 'icon': Icons.account_balance_wallet, 'url': 'paytmmp://$upiParams'},
      {'name': 'PhonePe', 'icon': Icons.mobile_friendly, 'url': 'phonepe://$upiParams'},
      {'name': 'WhatsApp Pay', 'icon': Icons.message, 'url': 'whatsapp://$upiParams'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select UPI App',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...apps.map((app) => ListTile(
              leading: Icon(app['icon'] as IconData, color: theme.colorScheme.primary),
              title: Text(app['name'] as String),
              onTap: () {
                Navigator.pop(context);
                onAppSelected(app['url'] as String);
              },
            )),
            const Divider(),
            ListTile(
              leading: Icon(Icons.qr_code_scanner, color: theme.colorScheme.secondary),
              title: const Text('Show QR Code (Fallback)'),
              onTap: () {
                Navigator.pop(context);
                onShowQrCode();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
