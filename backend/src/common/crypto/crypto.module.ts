import { Global, Module } from '@nestjs/common';
import { FieldEncryptionService } from './field-encryption.service';

/** Field-level encryption shared by every module that stores sensitive values. */
@Global()
@Module({ providers: [FieldEncryptionService], exports: [FieldEncryptionService] })
export class CryptoModule {}
