import 'package:cercly/features/auth/screens/phone_auth_screen.dart';
import 'package:cercly/features/auth/services/auth_service.dart';
import 'package:cercly/features/auth/services/auth_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakePhone extends AuthService {
  int sends = 0, verifies = 0;
  String? phone;
  bool invalid = true;
  @override
  Future<void> requestPhoneOtp(String value) async {
    sends++;
    phone = value;
  }

  @override
  Future<void> verifyPhoneOtp(String phone, String code) async {
    verifies++;
    if (invalid) throw const AuthException('private', code: 'otp_expired');
  }
}

void main() {
  test('valida sintaxis internacional E.164', () {
    for (final phone in ['+593991234567', '+14155552671', '+34612345678']) {
      expect(validarTelefono(phone), isNull);
    }
    for (final phone in [
      '',
      '0991234567',
      '+0123456789',
      '+593',
      '+1234567890123456',
      '+593 991234567',
      '+abcdefghi',
    ]) {
      expect(validarTelefono(phone), isNotNull);
    }
  });
  testWidgets('OTP solicita, limita reenvío, muestra error y verifica', (
    tester,
  ) async {
    final service = FakePhone();
    var now = DateTime(2026);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) =>
                    PhoneAuthScreen(service: service, now: () => now),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phone')),
      '+593991234567',
    );
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(service.sends, 1);
    expect(service.phone, '+593991234567');
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Reenviar código'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const ValueKey('otp')), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('incorrecto o ha vencido'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('otp')))
          .controller!
          .text,
      isEmpty,
    );
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();
    expect(service.sends, 2);
    service.invalid = false;
    await tester.enterText(find.byKey(const ValueKey('otp')), '654321');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(service.verifies, 2);
    expect(find.text('abrir'), findsOneWidget);
  });
  test('límites de solicitudes tienen mensaje comprensible', () {
    expect(
      AuthService.errorMessage(
        const AuthException('private', statusCode: '429'),
      ),
      contains('Demasiados intentos'),
    );
  });
}
