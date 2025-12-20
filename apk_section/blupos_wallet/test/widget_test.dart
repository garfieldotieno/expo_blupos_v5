// This is a basic Flutter widget test for BluPOS Wallet.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blupos_wallet/main.dart';

void main() {
  testWidgets('BluPOS Wallet app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BluPOSWalletApp());

    // Verify that our app shows the Activation page initially
    expect(find.text('Activation'), findsOneWidget);
    expect(find.text('Device Activation'), findsOneWidget);
    expect(find.text('Activate Device'), findsOneWidget);

    // Verify bottom navigation is present
    expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    expect(find.byIcon(Icons.analytics), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);

    // Test navigation to Reports page
    await tester.tap(find.byIcon(Icons.analytics));
    await tester.pump();

    // Verify Reports page is shown
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Transaction Reports'), findsOneWidget);

    // Test navigation to Wallet page
    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();

    // Verify Wallet page is shown
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('BluPOS Wallet'), findsOneWidget);
  });
}
