import { type Readable } from 'node:stream';

/** Injection token of the configured storage (`STORAGE_DRIVER`). */
export const FILE_STORAGE = Symbol('FILE_STORAGE');

/**
 * Where the bytes of uploaded files live. Only the files module talks to it: the rest of the
 * system refers to files by id and never sees a storage key or a public address.
 */
export interface FileStorage {
  /** Stores `data` under `key`. Never overwrites: a key is used once. */
  put(key: string, data: Buffer, contentType: string): Promise<void>;
  /** Streams the stored bytes. Throws when the key does not exist. */
  open(key: string): Promise<Readable>;
  /** Removes the bytes. Removing a key that does not exist is not an error. */
  remove(key: string): Promise<void>;
}
