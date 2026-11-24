import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/i18n/app_language.dart';

/// English / සිංහල / தமிழ் as three buttons; the chosen one is filled. Shown on Login and in More.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    return Row(
      children: [
        for (final language in AppLanguage.values) ...[
          if (language != AppLanguage.values.first) const SizedBox(width: 8),
          Expanded(
            child: language == current
                ? ShadButton(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () {},
                    child: _Name(language),
                  )
                : ShadButton.outline(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => ref.read(languageProvider.notifier).choose(language),
                    child: _Name(language),
                  ),
          ),
        ],
      ],
    );
  }
}

class _Name extends StatelessWidget {
  const _Name(this.language);

  final AppLanguage language;

  @override
  Widget build(BuildContext context) =>
      Text(language.nativeName, style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis);
}
