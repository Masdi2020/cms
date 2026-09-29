import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rukun/main.dart';
import 'package:rukun/screens/login.dart';

void main() {
  testWidgets('login validates credentials and calls authentication', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MyApp(
        home: LoginPage(
          onLogin: (email, password) async {
            calls++;
            expect(email, 'test@example.com');
            expect(password, 'password123');
          },
        ),
      ),
    );
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(find.text('Masukkan email atau username'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(
      find.byType(TextFormField).first,
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('login password visibility can be toggled', (tester) async {
    await tester.pumpWidget(MyApp(home: LoginPage(onLogin: (_, _) async {})));

    final passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
  });
}
