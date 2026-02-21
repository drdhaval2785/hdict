import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upi_pay/upi_pay.dart';

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

class _UpiOptionsList extends StatefulWidget {
  final VoidCallback onShowQrCode;

  const _UpiOptionsList({
    required this.onShowQrCode,
  });

  @override
  State<_UpiOptionsList> createState() => _UpiOptionsListState();
}

class _UpiOptionsListState extends State<_UpiOptionsList> {
  List<ApplicationMeta>? _apps;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledUpiApps();
  }

  Future<void> _loadInstalledUpiApps() async {
    try {
      final apps = await UpiPay().getInstalledUpiApplications(
        statusType: UpiApplicationDiscoveryAppStatusType.all,
      );
      
      final List<ApplicationMeta> verifiedApps = [];
      for (var app in apps) {
        if (io.Platform.isIOS) {
          // UpiPay blindly returns apps on iOS if they lack a discovery scheme.
          // Filter to only those we can actively verify are installed via schemes.
          if (app.upiApplication.discoveryCustomScheme != null) {
            final uri = Uri.parse('${app.upiApplication.discoveryCustomScheme}://');
            if (await canLaunchUrl(uri)) {
              verifiedApps.add(app);
            }
          }
        } else {
          // UpiPay uses PackageManager on Android which is generally reliable.
          verifiedApps.add(app);
        }
      }

      if (mounted) {
        setState(() {
          _apps = verifiedApps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apps = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onAppTap(ApplicationMeta app) async {
    Navigator.pop(context); // Close the bottom sheet
    
    try {
      final response = await UpiPay().initiateTransaction(
        app: app.upiApplication,
        receiverUpiAddress: 'drdhaval2785@okicici',
        receiverName: 'Dhaval Patel',
        transactionRef: 'DONATION_${DateTime.now().millisecondsSinceEpoch}',
        transactionNote: 'Donation to hdict',
        amount: '1.00', // Optional amount to prevent compile failure
      );

      if (mounted) {
        final status = response.status == UpiTransactionStatus.success
            ? 'Transaction Successful'
            : 'Transaction Failed or Cancelled';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch app: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select UPI App',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              )
            else if (_apps != null && _apps!.isNotEmpty)
              ..._apps!.map((app) => ListTile(
                leading: app.iconImage(40),
                title: Text(app.upiApplication.getAppName()),
                onTap: () => _onAppTap(app),
              ))
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No UPI apps found on this device.'),
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.qr_code_scanner, color: theme.colorScheme.secondary),
              title: const Text('Show QR Code (Fallback)'),
              onTap: () {
                Navigator.pop(context);
                widget.onShowQrCode();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
