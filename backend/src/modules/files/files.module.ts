import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { S3Client } from '@aws-sdk/client-s3';
import { AppConfigService } from '../../config/app-config.service';
import { DocumentTypesModule } from '../document-types/document-types.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { FilesController } from './controllers/files.controller';
import { StoredFileRepository } from './repositories/stored-file.repository';
import { STORED_FILE_MODEL, storedFileSchema } from './schemas/stored-file.schema';
import { FilesService } from './services/files.service';
import { FILE_STORAGE, type FileStorage } from './storage/file-storage';
import { LocalFileStorage } from './storage/local-file-storage';
import { S3FileStorage } from './storage/s3-file-storage';

/** Chooses the storage named by `STORAGE_DRIVER` (documentation/environment-variables.md). */
export function createFileStorage(config: AppConfigService): FileStorage {
  if (config.get('STORAGE_DRIVER') === 'local') {
    return new LocalFileStorage(config.get('STORAGE_LOCAL_ROOT'));
  }
  // The environment rules guarantee these are set when the driver is s3
  const endpoint = config.get('STORAGE_ENDPOINT');
  const client = new S3Client({
    region: config.get('STORAGE_REGION') ?? 'auto',
    ...(endpoint ? { endpoint, forcePathStyle: true } : {}),
    credentials: {
      accessKeyId: config.get('STORAGE_ACCESS_KEY') ?? '',
      secretAccessKey: config.get('STORAGE_SECRET_KEY') ?? '',
    },
  });
  return new S3FileStorage(client, config.get('STORAGE_BUCKET') ?? '');
}

/**
 * `files` — Platform domain (documentation/architecture.md §5). Private storage of uploaded
 * documents and their authenticated download (documentation/client-onboarding.md).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: STORED_FILE_MODEL, schema: storedFileSchema }]),
    RbacModule,
    DocumentTypesModule,
    OperatorsModule,
  ],
  controllers: [FilesController],
  providers: [
    StoredFileRepository,
    FilesService,
    { provide: FILE_STORAGE, inject: [AppConfigService], useFactory: createFileStorage },
  ],
  exports: [FilesService, MongooseModule],
})
export class FilesModule {}
