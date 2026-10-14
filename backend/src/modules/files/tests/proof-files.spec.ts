import { MAX_PROOF_BYTES, MAX_PROOFS_PER_SUBJECT, looksLikeText } from '../files_core.service';

describe('Proof file rules', () => {
  it('are the ones of the demos: 5 files, 600 KB each', () => {
    expect(MAX_PROOFS_PER_SUBJECT).toBe(5);
    expect(MAX_PROOF_BYTES).toBe(600 * 1024);
  });

  describe('a text file', () => {
    it('is plain readable text, including Telugu, Hindi and line breaks', () => {
      expect(looksLikeText(Buffer.from('Bus broke down.\r\nరెండు గంటలు ఆలస్యం\tOK', 'utf8'))).toBe(
        true,
      );
      expect(looksLikeText(Buffer.from('नमस्ते', 'utf8'))).toBe(true);
    });

    it('is not binary: a zero byte, bad UTF-8 or control characters', () => {
      expect(looksLikeText(Buffer.from([0x68, 0x00, 0x69]))).toBe(false);
      expect(looksLikeText(Buffer.from([0xff, 0xfe, 0xfd]))).toBe(false);
      expect(looksLikeText(Buffer.from('abc\u0007def', 'utf8'))).toBe(false);
    });
  });
});
