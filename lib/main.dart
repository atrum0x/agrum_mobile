import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/db/app_database.dart';
import 'core/i18n/app_language.dart';
import 'features/auth/state/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FSD 8: the phone app is portrait only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // The chosen language, so the first screen is already in it
  var language = AppLanguage.en;
  try {
    language = await LanguageStore.read(await AppDatabase.open());
  } catch (_) {
    // English until the database can be read
  }
  runApp(ProviderScope(
    overrides: [initialLanguageProvider.overrideWithValue(language)],
    child: const AgrumApp(),
  ));
}

class AgrumApp extends ConsumerWidget {
  const AgrumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return ShadApp.router(
      title: 'Agrum',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      // Material's own texts (dialogs, pickers) follow the chosen language too
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Every touch counts as activity for the LG-06 inactivity timeout. The key rebuilds every
      // screen in the new language; the router keeps the current page.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(language),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => ref.read(authControllerProvider.notifier).activity(),
          child: child,
        ),
      ),
    );
  }
}
