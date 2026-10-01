import {
  emailSchema,
  maskPhoneNumber,
  normalizePhoneNumber,
  phoneNumberSchema,
} from '../contact-identifiers';

describe('contact identifiers', () => {
  it.each([
    ['9876543210', '+919876543210'],
    ['98765 43210', '+919876543210'],
    ['+91 98765-43210', '+919876543210'],
    ['+14155550123', '+14155550123'],
  ])('normalises %s to %s', (input, expected) => {
    expect(normalizePhoneNumber(input)).toBe(expected);
    expect(phoneNumberSchema.parse(input)).toBe(expected);
  });

  it.each(['12345', '5876543210', '+0123456789', 'abcdefghij', '+91', ''])(
    'rejects %s',
    (input) => {
      expect(normalizePhoneNumber(input)).toBeUndefined();
      expect(phoneNumberSchema.safeParse(input).success).toBe(false);
    },
  );

  it('lower-cases and validates emails', () => {
    expect(emailSchema.parse('  Asha@Example.COM ')).toBe('asha@example.com');
    expect(emailSchema.safeParse('not-an-email').success).toBe(false);
  });

  it('masks phone numbers for logs', () => {
    expect(maskPhoneNumber('+919876543210')).toBe('+91******3210');
    expect(maskPhoneNumber('+91')).toBe('***');
  });
});
