import { Module } from '@nestjs/common';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { OperatorsExportController } from './operators_admin_manage';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { OperatorsController } from './controllers/operators.controller';
import { OperatorRepository } from './repositories/operator.repository';
import { OPERATOR_MODEL, operatorSchema } from './schemas/operator.schema';
import { OperatorsService } from './services/operators.service';

/**
 * `operators` — Supply domain (documentation/architecture.md §5). Registration, profile and
 * status of bus operators (documentation/catalogue-management.md). Documents, bank details and
 * staff arrive with operator onboarding.
 */
@Module({
  imports: [CatalogueSharedModule, 
    MongooseModule.forFeature([{ name: OPERATOR_MODEL, schema: operatorSchema }]),
    RbacModule,
  ],
  controllers: [OperatorsExportController, OperatorsController],
  providers: [OperatorRepository, OperatorsService],
  exports: [OperatorRepository, MongooseModule],
})
export class OperatorsModule {}
