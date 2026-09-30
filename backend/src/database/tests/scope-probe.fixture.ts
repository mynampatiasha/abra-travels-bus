import { type INestApplication, Injectable, Logger, Module } from '@nestjs/common';
import { InjectModel, MongooseModule } from '@nestjs/mongoose';
import { Test } from '@nestjs/testing';
import { type Model, Schema, type Types } from 'mongoose';
import { AppConfigModule } from '../../config/app-config.module';
import { validTestEnvironment } from '../../config/tests/valid-test-environment';
import { type ScopeFields } from '../data-scope.policy';
import { DatabaseModule } from '../database.module';
import { ScopedRepository } from '../scoped-repository.base';

/**
 * Test-only tenant collection used to exercise the transaction layer and ScopedRepository against
 * the real Docker replica set. Lives in the `abra_travels_test` database, which the e2e tests drop.
 * Not a business schema and never registered by the application.
 */
export const SCOPE_PROBE_MODEL = 'ScopeProbe';
export const SCOPE_PROBE_COLLECTION = 'test_scope_probes';

export interface ScopeProbe {
  operatorId: Types.ObjectId;
  partnerId?: Types.ObjectId;
  customerId?: Types.ObjectId;
  code: string;
  counter: number;
}

export const scopeProbeSchema = new Schema<ScopeProbe>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    partnerId: { type: Schema.Types.ObjectId },
    customerId: { type: Schema.Types.ObjectId },
    code: { type: String, required: true },
    counter: { type: Number, default: 0 },
  },
  { collection: SCOPE_PROBE_COLLECTION, timestamps: true },
);
// Same shape as real tenant collections: compound index starting with operatorId + a unique key
scopeProbeSchema.index({ operatorId: 1, createdAt: -1 });
scopeProbeSchema.index({ code: 1 }, { unique: true });

@Injectable()
export class ScopeProbeRepository extends ScopedRepository<ScopeProbe> {
  protected readonly scopeFields: ScopeFields = {
    operator: 'operatorId',
    partner: 'partnerId',
    owner: 'customerId',
  };

  /** Stand-in for a driver's trip assignments. */
  assignedIds: string[] = [];

  constructor(@InjectModel(SCOPE_PROBE_MODEL) model: Model<ScopeProbe>) {
    super(model);
  }

  protected override assignedRecordIds(): Promise<string[]> {
    return Promise.resolve(this.assignedIds);
  }
}

@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    MongooseModule.forFeature([{ name: SCOPE_PROBE_MODEL, schema: scopeProbeSchema }]),
  ],
  providers: [ScopeProbeRepository],
})
class ScopeProbeTestModule {}

/** Boots config + database layer (incl. start-up verification and index bootstrap). */
export async function createDatabaseTestApplication(): Promise<INestApplication> {
  Object.assign(process.env, validTestEnvironment());
  Logger.overrideLogger(['error']);
  const moduleRef = await Test.createTestingModule({ imports: [ScopeProbeTestModule] }).compile();
  const app = moduleRef.createNestApplication();
  await app.init();
  return app;
}
