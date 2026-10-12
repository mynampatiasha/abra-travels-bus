import { Injectable } from '@nestjs/common';
import { type ClientSession, type Types } from 'mongoose';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { type AuditAction } from '../../audit-logs/schemas/audit-log.schema';
import { AuditLogService } from '../../audit-logs/services/audit-log.service';
import { EffectivePermissionsService } from '../../rbac/services/effective-permissions.service';

/** Writes the onboarding entries of the audit trail, inside the transaction of the change. */
@Injectable()
export class OnboardingAuditor {
  constructor(
    private readonly audit: AuditLogService,
    private readonly permissions: EffectivePermissionsService,
  ) {}

  async record(
    input: {
      actor: AuthenticatedUserActor;
      action: AuditAction;
      entityType: 'onboarding_submission' | 'onboarding_invitation';
      entityId: Types.ObjectId;
      operatorId: Types.ObjectId;
      before: Record<string, unknown>;
      after: Record<string, unknown>;
      reason?: string | undefined;
      client?: ClientRequestInfo | undefined;
    },
    session: ClientSession,
  ): Promise<void> {
    const actorRoleKeys = (await this.permissions.forActor(input.actor)).roleKeys;
    await this.audit.record(
      {
        actor: input.actor,
        actorRoleKeys,
        action: input.action,
        entityType: input.entityType,
        entityId: input.entityId,
        operatorId: input.operatorId,
        before: input.before,
        after: input.after,
        ...(input.reason ? { reason: input.reason } : {}),
        ...(input.client ? { client: input.client } : {}),
      },
      session,
    );
  }
}
