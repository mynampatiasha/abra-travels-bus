import { resolveRequestId } from '../request-context/request-id.middleware';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

describe('resolveRequestId', () => {
  it('keeps a safe caller-supplied id', () => {
    expect(resolveRequestId('lb-7f3a9c21-trace')).toBe('lb-7f3a9c21-trace');
  });

  it('generates a UUID when no id is supplied', () => {
    expect(resolveRequestId(undefined)).toMatch(UUID);
  });

  it.each([
    'short',
    'has spaces in it',
    'x'.repeat(129),
    'inject\nnewline-value',
    '<script>alert</script>',
  ])('replaces an unsafe id (%s) with a generated UUID', (unsafe) => {
    expect(resolveRequestId(unsafe)).toMatch(UUID);
  });
});
