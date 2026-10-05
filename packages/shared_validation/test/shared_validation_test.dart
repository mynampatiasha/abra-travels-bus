import 'package:shared_validation/shared_validation.dart';
import 'package:test/test.dart';

void main() {
  group('PhoneNumbers (same rule as the backend)', () {
    test('normalises to E.164', () {
      expect(PhoneNumbers.normalize('9876543210'), '+919876543210');
      expect(PhoneNumbers.normalize('98765 43210'), '+919876543210');
      expect(PhoneNumbers.normalize('+91 98765-43210'), '+919876543210');
      expect(PhoneNumbers.normalize('+14155550123'), '+14155550123');
    });

    test('rejects unusable numbers', () {
      for (final input in [
        '12345',
        '5876543210',
        '+0123456789',
        'abcdefghij',
        '+91',
        '',
      ]) {
        expect(PhoneNumbers.normalize(input), isNull, reason: input);
      }
    });

    test('validates', () {
      expect(PhoneNumbers.validate(null), InputProblem.required);
      expect(PhoneNumbers.validate('  '), InputProblem.required);
      expect(PhoneNumbers.validate('12345'), InputProblem.invalidPhone);
      expect(PhoneNumbers.validate('9876543210'), isNull);
    });

    test('masks for display', () {
      expect(PhoneNumbers.mask('+919876543210'), '+91******3210');
      expect(PhoneNumbers.mask('+91'), '***');
    });
  });

  group('Emails', () {
    test('normalises and validates', () {
      expect(Emails.normalize('  Asha@Example.COM '), 'asha@example.com');
      expect(Emails.validate('asha@example.com'), isNull);
      expect(Emails.validate('Asha.Kumar+travel@mail.example.in'), isNull);
      for (final input in [
        'not-an-email',
        'a@b',
        '@example.com',
        'a b@example.com',
      ]) {
        expect(
          Emails.validate(input),
          InputProblem.invalidEmail,
          reason: input,
        );
      }
    });

    test('required unless optional', () {
      expect(Emails.validate(''), InputProblem.required);
      expect(Emails.validate(null, isRequired: false), isNull);
      expect(Emails.validate('', isRequired: false), isNull);
    });
  });

  group('Passwords (backend policy)', () {
    test('length limits are 10 to 128', () {
      expect(Passwords.validateNew(''), InputProblem.required);
      expect(Passwords.validateNew('123456789'), InputProblem.passwordTooShort);
      expect(Passwords.validateNew('x' * 129), InputProblem.passwordTooLong);
      expect(Passwords.validateNew('violet-river-lantern'), isNull);
      expect(InputLimits.passwordMinLength, 10);
      expect(InputLimits.passwordMaxLength, 128);
    });

    test('rejects repeated characters', () {
      expect(
        Passwords.validateNew('aaaaaaaaaaaa'),
        InputProblem.passwordTooSimple,
      );
      expect(
        Passwords.validateNew('abababababab'),
        InputProblem.passwordTooSimple,
      );
    });

    test('rejects passwords built from the account identifiers', () {
      const email = 'asha.kumar@example.com';
      const phone = '+919876543210';
      for (final password in [
        'asha.kumar@example.com',
        'Asha.Kumar-2026',
        'my9876543210pass',
      ]) {
        expect(
          Passwords.validateNew(password, email: email, phone: phone),
          InputProblem.passwordContainsIdentifier,
          reason: password,
        );
      }
      expect(
        Passwords.validateNew(
          'violet-river-lantern',
          email: email,
          phone: phone,
        ),
        isNull,
      );
    });
  });

  group('codes and names', () {
    test('OTP is 4 to 8 digits, TOTP exactly 6', () {
      expect(VerificationCodes.validateOtp('123456'), isNull);
      expect(VerificationCodes.validateOtp('1234'), isNull);
      expect(VerificationCodes.validateOtp('123'), InputProblem.invalidCode);
      expect(VerificationCodes.validateOtp('12a456'), InputProblem.invalidCode);
      expect(VerificationCodes.validateOtp(''), InputProblem.required);
      expect(VerificationCodes.validateTotp('123456'), isNull);
      expect(VerificationCodes.validateTotp('12345'), InputProblem.invalidCode);
      expect(VerificationCodes.validateTotp(null), InputProblem.required);
    });

    test('names are 2 to 120 characters', () {
      expect(PersonNames.validate(' '), InputProblem.required);
      expect(PersonNames.validate('A'), InputProblem.nameTooShort);
      expect(PersonNames.validate('Asha'), isNull);
      expect(PersonNames.validate('ಆಶಾ ಸುಬ್ರಹ್ಮಣ್ಯಂ'), isNull);
      expect(PersonNames.validate('x' * 121), InputProblem.nameTooLong);
    });
  });
}
