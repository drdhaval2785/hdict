import 'package:flutter/material.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(theme, 'Appearance'),
          ListTile(
            title: const Text('Font Family'),
            subtitle: Text(settings.fontFamily),
            trailing: const Icon(Icons.font_download),
            onTap: () => _showFontPicker(context, settings),
          ),
          ListTile(
            title: const Text('Font Size'),
            subtitle: Text('${settings.fontSize.toInt()}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => settings.setFontSize(settings.fontSize - 1),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => settings.setFontSize(settings.fontSize + 1),
                ),
              ],
            ),
          ),
          _buildColorTile(
            context,
            'Background Colour',
            settings.backgroundColor,
            (color) => settings.setBackgroundColor(color),
          ),
          _buildColorTile(
            context,
            'Font Colour (Headings)',
            settings.fontColor,
            (color) => settings.setFontColor(color),
          ),
          _buildColorTile(
            context,
            'Text Colour (Content)',
            settings.textColor,
            (color) => settings.setTextColor(color),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'Search & Preview'),
          ListTile(
            title: const Text('Preview Lines'),
            subtitle: const Text('Number of lines to show in suggestions'),
            trailing: DropdownButton<int>(
              value: settings.previewLines,
              items: [1, 2, 3, 4, 5]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (value) {
                if (value != null) settings.setPreviewLines(value);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Fuzzy Search'),
            subtitle: const Text('Search for similar words'),
            value: settings.isFuzzySearchEnabled,
            onChanged: (value) => settings.setFuzzySearch(value),
          ),
          SwitchListTile(
            title: const Text('Search Within Definitions'),
            subtitle: const Text('Look for your query inside meanings too'),
            value: settings.isSearchWithinDefinitionsEnabled,
            onChanged: (value) => settings.setSearchWithinDefinitions(value),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'Dictionary Interaction'),
          SwitchListTile(
            title: const Text('Allow Tap on Meanings'),
            subtitle: const Text('Tap words in meanings to look them up'),
            value: settings.isTapOnMeaningEnabled,
            onChanged: (value) => settings.setTapOnMeaning(value),
          ),
          SwitchListTile(
            title: const Text('Open Popup on Tap'),
            subtitle: const Text(
              'Show meaning in a popup instead of full screen',
            ),
            value: settings.isOpenPopupOnTap,
            onChanged: (value) => settings.setOpenPopup(value),
          ),
          const Divider(),
          _buildSectionHeader(theme, 'History'),
          ListTile(
            title: const Text('Retain Search History'),
            subtitle: Text(
              'Keep history for ${settings.historyRetentionDays} days',
            ),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(border: InputBorder.none),
                onSubmitted: (value) {
                  final days = int.tryParse(value);
                  if (days != null) settings.setHistoryRetentionDays(days);
                },
                controller: TextEditingController(
                  text: '${settings.historyRetentionDays}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildColorTile(
    BuildContext context,
    String title,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
        ),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            Color pickedColor = currentColor;
            return AlertDialog(
              title: Text('Pick $title'),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (color) => pickedColor = color,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    onColorChanged(pickedColor);
                    Navigator.pop(context);
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFontPicker(BuildContext context, SettingsProvider settings) {
    final fonts = ['Roboto', 'Inter', 'Open Sans', 'Lato', 'Montserrat'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Font Family'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    fonts[index],
                    style: TextStyle(fontFamily: fonts[index]),
                  ),
                  onTap: () {
                    settings.setFontFamily(fonts[index]);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
