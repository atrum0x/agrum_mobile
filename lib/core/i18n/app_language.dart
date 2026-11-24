import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'app_strings.dart';
import 'strings_en.dart';
import 'strings_si.dart';
import 'strings_ta.dart';

/// The app's languages, the same three as the web app. Each is named in its own script so it can
/// be found whatever language is showing.
enum AppLanguage {
  en('English', Locale('en'), EnStrings()),
  si('සිංහල', Locale('si'), SiStrings()),
  ta('தமிழ்', Locale('ta'), TaStrings());

  const AppLanguage(this.nativeName, this.locale, this.strings);

  final String nativeName;
  final Locale locale;
  final AppStrings strings;

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((language) => language.name == code, orElse: () => AppLanguage.en);
}

/// The phone remembers the choice in its own database, for every user of the phone (the Login
/// screen needs it before anyone logs in).
class LanguageStore {
  const LanguageStore._();

  static const _key = 'app_language';

  static Future<AppLanguage> read(Database db) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [_key]);
    return AppLanguage.fromCode(rows.isEmpty ? null : rows.single['value'] as String?);
  }

  static Future<void> write(Database db, AppLanguage language) =>
      db.insert('meta', {'key': _key, 'value': language.name}, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// The language read at startup; main() overrides it so the first frame is already translated.
final initialLanguageProvider = Provider<AppLanguage>((ref) => AppLanguage.en);

class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final language = ref.watch(initialLanguageProvider);
    setCurrentStrings(language.strings);
    return language;
  }

  Future<void> choose(AppLanguage language) async {
    if (language == state) return;
    setCurrentStrings(language.strings);
    state = language;
    await LanguageStore.write(await ref.read(appDatabaseProvider.future), language);
  }
}

final languageProvider = NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);
