import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'About Us',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/hdict_logo.png',
                height: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                'hdict',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Version 1.2.2', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              const Text(
                'Vibe coded by Dr. Dhaval Patel',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'drdhaval2785@gmail.com',
                  );
                  if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                  }
                },
                child: const Text(
                  'drdhaval2785@gmail.com',
                  style: TextStyle(
                    color: Color(0xFFFFAB40),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Optimized for speed and simplicity.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dedicated to Hiral.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFAB40),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'To report issues or request new features, please use:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final Uri githubUri = Uri.parse('https://github.com/drdhaval2785/hdict/');
                  if (await canLaunchUrl(githubUri)) {
                    await launchUrl(githubUri);
                  }
                },
                child: const Text(
                  'https://github.com/drdhaval2785/hdict/',
                  style: TextStyle(
                    color: Color(0xFFFFAB40),
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
