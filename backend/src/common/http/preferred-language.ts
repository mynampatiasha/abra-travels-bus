/**
 * Language of the first entry of an `Accept-Language` header, as a lower-case language code
 * (`kn-IN,kn;q=0.9` -> `kn`). Undefined when the header is missing or not a language tag.
 */
export function preferredLanguage(header: string | undefined): string | undefined {
  const first = header?.split(',')[0]?.split(';')[0]?.trim();
  const language = first?.split('-')[0]?.toLowerCase();
  return language && /^[a-z]{2,3}$/.test(language) ? language : undefined;
}
