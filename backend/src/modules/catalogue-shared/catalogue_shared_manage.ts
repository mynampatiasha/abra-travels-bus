import { Controller, Delete, Module, Param, Post, Req, type Type } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type PermissionKey } from '../rbac/permissions/permission-catalog';
import { RbacModule } from '../rbac/rbac.module';
import {
  CATALOGUE_KINDS,
  type CatalogueKind,
  CatalogueDeletionService,
  type DeletionResult,
} from './catalogue_shared_manage.service';

/*
 * Delete and restore routes of the catalogue records (documentation/abra-master-plan.md,
 * Phase 1 step 1). One class is made per kind from the same code, so every record behaves the
 * same: `DELETE /<base>/:id` soft-deletes (refused with a sentence while other records use it) and
 * `POST /<base>/:id/restore` is the Undo. Both need the module's delete permission, which only
 * the Edit+Delete level of the access matrix holds.
 */

export class CatalogueIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

interface DeletionRoute {
  readonly kind: CatalogueKind;
  readonly base: string;
  readonly permission: PermissionKey;
}

export const DELETION_ROUTES: readonly DeletionRoute[] = [
  { kind: 'city', base: 'catalogue/cities', permission: 'catalogue.delete' },
  { kind: 'location', base: 'catalogue/locations', permission: 'catalogue.delete' },
  { kind: 'busType', base: 'catalogue/bus-types', permission: 'catalogue.delete' },
  { kind: 'documentType', base: 'catalogue/document-types', permission: 'documents.delete' },
  { kind: 'operator', base: 'catalogue/operators', permission: 'operators.delete' },
  { kind: 'invitation', base: 'onboarding/invitations', permission: 'operators.delete' },
];

function deletionController({ kind, base, permission }: DeletionRoute): Type<unknown> {
  const label = CATALOGUE_KINDS[kind].label;

  @ApiTags('catalogue')
  @Controller(base)
  class DeletionController {
    constructor(private readonly deletion: CatalogueDeletionService) {}

    @Delete(':id')
    @RequirePermission(permission)
    @ApiOperation({
      summary: `Delete a ${label}`,
      description:
        `Requires ${permission}. Soft delete: the ${label} disappears from every list but can be ` +
        'restored. Refused (RESOURCE_IN_USE) while other records use it. Audited.',
    })
    remove(
      @CurrentActor() actor: AuthenticatedUserActor,
      @Param() params: CatalogueIdParamDto,
      @Req() request: Request,
    ): Promise<DeletionResult> {
      return this.deletion.delete(kind, actor, params.id, clientRequestInfo(request));
    }

    @Post(':id/restore')
    @RequirePermission(permission)
    @ApiOperation({
      summary: `Restore a deleted ${label}`,
      description: `Requires ${permission}. The Undo of a delete. Audited.`,
    })
    restore(
      @CurrentActor() actor: AuthenticatedUserActor,
      @Param() params: CatalogueIdParamDto,
      @Req() request: Request,
    ): Promise<DeletionResult> {
      return this.deletion.restore(kind, actor, params.id, clientRequestInfo(request));
    }
  }

  Object.defineProperty(DeletionController, 'name', { value: `${kind}DeletionController` });
  return DeletionController;
}

@Module({
  imports: [RbacModule],
  controllers: DELETION_ROUTES.map(deletionController),
  providers: [CatalogueDeletionService],
  exports: [CatalogueDeletionService],
})
export class CatalogueSharedModule {}
