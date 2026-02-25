import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'tr.dart';

Future<void> showAppSettingsSheet(BuildContext context) {
  final settings = AppScope.settingsOf(context);

  return showModalBottomSheet<void>(
    context: context,
    builder: (_) {
      return AnimatedBuilder(
        animation: settings,
        builder: (_, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(context, 'settings'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: settings.isDark,
                    onChanged: settings.toggleDark,
                    title: Text(tr(context, 'theme_dark')),
                  ),
                  ListTile(
                    title: Text(tr(context, 'language')),
                    subtitle: Text(
                      settings.locale.languageCode == 'ru'
                          ? tr(context, 'lang_ru')
                          : tr(context, 'lang_en'),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.locale.languageCode,
                      items: [
                        DropdownMenuItem(
                          value: 'ru',
                          child: Text(tr(context, 'lang_ru')),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(tr(context, 'lang_en')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        settings.setLocale(Locale(v));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
