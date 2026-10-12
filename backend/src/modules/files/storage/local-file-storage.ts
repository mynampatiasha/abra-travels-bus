import { createReadStream } from 'node:fs';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import { dirname, resolve, sep } from 'node:path';
import { type Readable } from 'node:stream';
import { type FileStorage } from './file-storage';

/**
 * Stores files in a folder on the server's disk. For development and single-server tests only:
 * `STORAGE_DRIVER=local` is refused in production (environment rules), where the S3 driver is used.
 */
export class LocalFileStorage implements FileStorage {
  private readonly root: string;

  constructor(root: string) {
    this.root = resolve(root);
  }

  /** The content type is not kept: the files record holds it, and disk has no use for it. */
  async put(key: string, data: Buffer, _contentType?: string): Promise<void> {
    const path = this.pathOf(key);
    await mkdir(dirname(path), { recursive: true });
    // 'wx': fail instead of replacing an existing file
    await writeFile(path, data, { flag: 'wx' });
  }

  // `async`, so an invalid key rejects like every other failure instead of throwing at the call
  async open(key: string): Promise<Readable> {
    const stream = createReadStream(this.pathOf(key));
    return new Promise((resolveStream, reject) => {
      stream.once('open', () => resolveStream(stream));
      stream.once('error', reject);
    });
  }

  async remove(key: string): Promise<void> {
    try {
      await unlink(this.pathOf(key));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }

  /** The path of `key`, which can never leave the storage folder. */
  private pathOf(key: string): string {
    const path = resolve(this.root, key);
    if (!path.startsWith(this.root + sep)) throw new Error('Storage key is outside the storage root');
    return path;
  }
}
