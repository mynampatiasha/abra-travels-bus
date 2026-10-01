import { Controller, type ExecutionContext, Get } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthenticatedOnly } from '../../../common/decorators/authenticated-only.decorator';
import { PublicEndpoint } from '../../../common/decorators/public-endpoint.decorator';
import { ApiException } from '../../../common/errors/api-exception';
import {
  type AuthenticatedUserActor,
  type RequestActor,
  systemActor,
} from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import { RequirePermission } from '../decorators/require-permission.decorator';
import { PermissionGuard } from '../guards/permission.guard';
import { type AuthorizationService } from '../services/authorization.service';
import {
  type ControllerClass,
  findUndeclaredEndpoints,
} from '../services/endpoint-access-declaration.check';

@Controller('probe')
class ProbeController {
  @Get('open')
  @PublicEndpoint()
  open(): void {}

  @Get('mine')
  @AuthenticatedOnly()
  mine(): void {}

  @Get('bookings')
  @RequirePermission('bookings.read')
  bookings(): void {}

  @Get('both')
  @RequirePermission('bookings.read', 'bookings.cancel')
  both(): void {}

  @Get('forgotten')
  forgotten(): void {}

  notARoute(): void {}
}

@Controller('reports')
@RequirePermission('reports.read')
class ReportsController {
  @Get()
  list(): void {}

  @Get('audit')
  @RequirePermission('audit.read')
  audit(): void {}
}

const ACTOR: AuthenticatedUserActor = {
  actorType: 'USER',
  userId: 'user-1',
  dataScope: { type: 'OWN_OPERATOR', operatorIds: ['op'] },
  userType: 'OPERATOR_STAFF',
  sessionId: 'session',
  permissionVersion: 1,
  roleIds: [],
  mfaEnrollmentPending: false,
};

function context(
  handler: string,
  controller: new () => object = ProbeController,
  type = 'http',
): ExecutionContext {
  const prototype = controller.prototype as Record<string, () => void>;
  return {
    getType: () => type,
    getHandler: () => prototype[handler],
    getClass: () => controller,
  } as unknown as ExecutionContext;
}

function guardHolding(...held: string[]) {
  const required: string[] = [];
  const authorization = {
    require: (_actor: RequestActor, permission: string) => {
      required.push(permission);
      return held.includes(permission)
        ? Promise.resolve()
        : Promise.reject(new ApiException('PERMISSION_DENIED', 'denied'));
    },
  } as unknown as AuthorizationService;
  return { guard: new PermissionGuard(new Reflector(), authorization), required };
}

function run(actor: RequestActor | undefined, work: () => Promise<boolean>): Promise<boolean> {
  return RequestContextService.run({ requestId: 'guard', ...(actor ? { actor } : {}) }, work);
}

async function codeOf(work: Promise<unknown>): Promise<string | undefined> {
  try {
    await work;
    return undefined;
  } catch (error) {
    if (error instanceof ApiException) return error.code;
    throw error;
  }
}

describe('PermissionGuard', () => {
  it('public endpoints need no actor and no permission', async () => {
    const { guard, required } = guardHolding();
    await expect(run(undefined, () => guard.canActivate(context('open')))).resolves.toBe(true);
    expect(required).toEqual([]);
  });

  it('non-HTTP contexts are not guarded here', async () => {
    const { guard } = guardHolding();
    await expect(guard.canActivate(context('bookings', ProbeController, 'rpc'))).resolves.toBe(
      true,
    );
  });

  it('no authenticated actor → UNAUTHENTICATED (401)', async () => {
    const { guard } = guardHolding('bookings.read');
    for (const handler of ['mine', 'bookings', 'forgotten']) {
      expect(await codeOf(run(undefined, () => guard.canActivate(context(handler))))).toBe(
        'UNAUTHENTICATED',
      );
    }
    // A SYSTEM actor never comes from a request and is not accepted as a caller
    expect(
      await codeOf(run(systemActor('job'), () => guard.canActivate(context('bookings')))),
    ).toBe('UNAUTHENTICATED');
  });

  it('authenticated-only endpoints accept any authenticated user without a permission check', async () => {
    const { guard, required } = guardHolding();
    await expect(run(ACTOR, () => guard.canActivate(context('mine')))).resolves.toBe(true);
    expect(required).toEqual([]);
  });

  it('with the permission → allowed; without it → PERMISSION_DENIED (403)', async () => {
    await expect(
      run(ACTOR, () => guardHolding('bookings.read').guard.canActivate(context('bookings'))),
    ).resolves.toBe(true);
    expect(
      await codeOf(
        run(ACTOR, () => guardHolding('reports.read').guard.canActivate(context('bookings'))),
      ),
    ).toBe('PERMISSION_DENIED');
  });

  it('several permissions are all required', async () => {
    expect(
      await codeOf(
        run(ACTOR, () => guardHolding('bookings.read').guard.canActivate(context('both'))),
      ),
    ).toBe('PERMISSION_DENIED');
    const both = guardHolding('bookings.read', 'bookings.cancel');
    await expect(run(ACTOR, () => both.guard.canActivate(context('both')))).resolves.toBe(true);
    expect(both.required).toEqual(['bookings.read', 'bookings.cancel']);
  });

  it('a controller-level permission applies to its handlers; a handler-level one replaces it', async () => {
    const reportsOnly = guardHolding('reports.read');
    await expect(
      run(ACTOR, () => reportsOnly.guard.canActivate(context('list', ReportsController))),
    ).resolves.toBe(true);
    expect(
      await codeOf(
        run(ACTOR, () => reportsOnly.guard.canActivate(context('audit', ReportsController))),
      ),
    ).toBe('PERMISSION_DENIED');
  });

  it('an endpoint that declares nothing is denied (fail closed)', async () => {
    const everything = guardHolding('bookings.read', 'reports.read', 'audit.read');
    expect(await codeOf(run(ACTOR, () => everything.guard.canActivate(context('forgotten'))))).toBe(
      'PERMISSION_DENIED',
    );
  });
});

describe('findUndeclaredEndpoints (start-up check)', () => {
  it('reports route handlers without an access declaration, and only those', () => {
    expect(findUndeclaredEndpoints([ProbeController, ReportsController])).toEqual([
      'ProbeController.forgotten: no access declaration',
    ]);
  });

  it('accepts controllers where everything is declared', () => {
    expect(findUndeclaredEndpoints([ReportsController])).toEqual([]);
  });

  it('reports a permission that is not in the catalogue', () => {
    const decorate = RequirePermission as unknown as (key: string) => MethodDecorator;
    class TypoController {
      @Get()
      @decorate('bookings.raed')
      list(): void {}
    }
    Controller('typo')(TypoController);
    expect(findUndeclaredEndpoints([TypoController as ControllerClass])).toEqual([
      'TypoController.list: unknown permission "bookings.raed"',
    ]);
  });
});
