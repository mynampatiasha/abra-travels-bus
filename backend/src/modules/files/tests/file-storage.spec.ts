import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { displayNameOf } from '../services/files.service';
import { detectMimeType } from '../storage/file-signature';
import { LocalFileStorage } from '../storage/local-file-storage';
import { S3FileStorage } from '../storage/s3-file-storage';

const PDF = Buffer.from('%PDF-1.7\n%test');
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('rest'),
]);
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00]);

async function read(stream: Readable): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of stream) chunks.push(Buffer.from(chunk as Uint8Array));
  return Buffer.concat(chunks);
}

describe('detectMimeType', () => {
  it('knows PDF, JPEG and PNG by their first bytes', () => {
    expect(detectMimeType(PDF)).toBe('application/pdf');
    expect(detectMimeType(JPEG)).toBe('image/jpeg');
    expect(detectMimeType(PNG)).toBe('image/png');
  });

  it('refuses everything else, whatever its name says', () => {
    expect(detectMimeType(Buffer.from('<html><script>alert(1)</script>'))).toBeUndefined();
    expect(detectMimeType(Buffer.from('MZ\x90\x00 an executable'))).toBeUndefined();
    expect(detectMimeType(Buffer.alloc(0))).toBeUndefined();
    expect(detectMimeType(Buffer.from('%PD'))).toBeUndefined();
  });
});

describe('displayNameOf', () => {
  it('keeps a normal name and drops folders and control characters', () => {
    expect(displayNameOf('RC book.pdf', 'pdf')).toBe('RC book.pdf');
    expect(displayNameOf('..\\..\\secret\\rc.pdf', 'pdf')).toBe('rc.pdf');
    expect(displayNameOf('a/b/c.png', 'png')).toBe('c.png');
    expect(displayNameOf('bad\u0000name\n.pdf', 'pdf')).toBe('badname.pdf');
  });

  it('decodes a UTF-8 name that the upload parser read as Latin-1', () => {
    const latin1 = Buffer.from('బస్సు.pdf', 'utf8').toString('latin1');
    expect(displayNameOf(latin1, 'pdf')).toBe('బస్సు.pdf');
  });

  it('falls back to a generic name and bounds the length', () => {
    expect(displayNameOf('', 'pdf')).toBe('document.pdf');
    expect(displayNameOf('..', 'png')).toBe('document.png');
    expect(displayNameOf(`${'x'.repeat(500)}.pdf`, 'pdf').length).toBe(200);
  });
});

describe('LocalFileStorage', () => {
  let root: string;
  let storage: LocalFileStorage;

  beforeEach(async () => {
    root = await mkdtemp(join(tmpdir(), 'abra-files-'));
    storage = new LocalFileStorage(root);
  });

  afterEach(async () => {
    await rm(root, { recursive: true, force: true });
  });

  it('stores, reads back and removes a file', async () => {
    await storage.put('op1/a.pdf', PDF, 'application/pdf');
    expect(await read(await storage.open('op1/a.pdf'))).toEqual(PDF);
    expect((await readFile(join(root, 'op1', 'a.pdf'))).equals(PDF)).toBe(true);
    await storage.remove('op1/a.pdf');
    await expect(storage.open('op1/a.pdf')).rejects.toThrow();
    await expect(storage.remove('op1/a.pdf')).resolves.toBeUndefined();
  });

  it('never replaces an existing file', async () => {
    await storage.put('op1/a.pdf', PDF, 'application/pdf');
    await expect(storage.put('op1/a.pdf', PNG, 'image/png')).rejects.toThrow();
    expect(await read(await storage.open('op1/a.pdf'))).toEqual(PDF);
  });

  it('refuses a key that points outside the storage folder', async () => {
    await expect(storage.put('../escape.pdf', PDF, 'application/pdf')).rejects.toThrow(
      /outside the storage root/,
    );
    await expect(storage.open('../../etc/passwd')).rejects.toThrow(/outside the storage root/);
    await expect(storage.remove('/etc/passwd')).rejects.toThrow(/outside the storage root/);
  });
});

describe('S3FileStorage', () => {
  it('sends the right commands to the bucket', async () => {
    const sent: unknown[] = [];
    const client = {
      send: (command: unknown) => {
        sent.push(command);
        return Promise.resolve(
          command instanceof GetObjectCommand ? { Body: Readable.from([PDF]) } : {},
        );
      },
    };
    const storage = new S3FileStorage(client as never, 'abra-documents');

    await storage.put('op1/a.pdf', PDF, 'application/pdf');
    expect(await read(await storage.open('op1/a.pdf'))).toEqual(PDF);
    await storage.remove('op1/a.pdf');

    const [put, get, remove] = sent;
    expect(put).toBeInstanceOf(PutObjectCommand);
    expect((put as PutObjectCommand).input).toMatchObject({
      Bucket: 'abra-documents',
      Key: 'op1/a.pdf',
      ContentType: 'application/pdf',
      IfNoneMatch: '*',
    });
    expect(get).toBeInstanceOf(GetObjectCommand);
    expect(remove).toBeInstanceOf(DeleteObjectCommand);
  });

  it('fails when the bucket returns no readable body', async () => {
    const storage = new S3FileStorage({ send: () => Promise.resolve({}) } as never, 'b');
    await expect(storage.open('x')).rejects.toThrow(/no readable body/);
  });
});
