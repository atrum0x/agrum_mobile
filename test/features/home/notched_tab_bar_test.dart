import 'package:agrum_mobile/features/home/ui/app_shell.dart';
import 'package:agrum_mobile/features/home/ui/notched_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every tab, moves the notch to the tapped one', (tester) async {
    const tabs = [AppTab.home, AppTab.attendance, AppTab.weighing, AppTab.more];
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          bottomNavigationBar: NotchedTabBar(
            tabs: tabs,
            selected: selected,
            onSelect: (i) => setState(() => selected = i),
          ),
        ),
      ),
    ));

    for (final tab in tabs) {
      expect(find.text(tab.label), findsOneWidget);
    }

    await tester.tap(find.text('Weighing'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
}
