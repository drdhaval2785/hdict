import 'package:flutter/material.dart';
import 'package:hdict/core/theme/app_theme.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/features/home/home_screen.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.initializeDatabaseFactory();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SettingsProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'hdict',
      theme: AppTheme.getTheme(Brightness.light, settings.fontFamily),
      darkTheme: AppTheme.getTheme(Brightness.dark, settings.fontFamily),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
