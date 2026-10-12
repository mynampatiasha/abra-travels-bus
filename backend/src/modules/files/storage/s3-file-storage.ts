import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  type S3Client,
} from '@aws-sdk/client-s3';
import { Readable } from 'node:stream';
import { type FileStorage } from './file-storage';

/**
 * Stores files in a private S3-compatible bucket (AWS S3, Cloudflare R2, MinIO...). The bucket
 * must not allow public reads: files are only served through the authenticated API.
 */
export class S3FileStorage implements FileStorage {
  constructor(
    private readonly client: Pick<S3Client, 'send'>,
    private readonly bucket: string,
  ) {}

  async put(key: string, data: Buffer, contentType: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: data,
        ContentType: contentType,
        // never replace an existing object
        IfNoneMatch: '*',
      }),
    );
  }

  async open(key: string): Promise<Readable> {
    const response = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
    );
    if (!(response.Body instanceof Readable)) throw new Error('Storage returned no readable body');
    return response.Body;
  }

  async remove(key: string): Promise<void> {
    // S3 answers success for a key that is not there
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}
