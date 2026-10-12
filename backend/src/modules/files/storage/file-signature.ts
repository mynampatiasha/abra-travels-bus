import { type DocumentMimeType } from '../../document-types/schemas/document-type.schema';

/**
 * The real type of a file, read from its first bytes. The type a browser declares and the file
 * name can both be faked, so neither is trusted. Returns undefined for anything else.
 */
export function detectMimeType(data: Buffer): DocumentMimeType | undefined {
  if (data.length >= 5 && data.subarray(0, 5).toString('latin1') === '%PDF-') {
    return 'application/pdf';
  }
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    data.length >= 8 &&
    data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'image/png';
  }
  return undefined;
}

export const FILE_EXTENSIONS: Record<DocumentMimeType, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};
