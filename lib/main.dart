import 'package:flutter/material.dart';
import 'package:hdict/core/theme/app_theme.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/features/home/home_screen.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.initializeDatabaseFactory();

  // Pre-warm all dictionary readers in parallel (~200-250ms)
  // This eliminates cold SAF read penalty on first search
  await DictionaryManager.instance.preWarmReaders();

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
      themeMode: settings.appThemeMode == AppThemeMode.light
          ? ThemeMode.light
          : (settings.appThemeMode == AppThemeMode.dark
                ? ThemeMode.dark
                : ThemeMode.system),
      home: const HomeScreen(),
    );
  }
}
