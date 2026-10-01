import { Injectable, type OnApplicationBootstrap } from '@nestjs/common';
import { PATH_METADATA } from '@nestjs/common/constants';
import { DiscoveryService, MetadataScanner, Reflector } from '@nestjs/core';
import { IS_AUTHENTICATED_ONLY } from '../../../common/decorators/authenticated-only.decorator';
import { IS_PUBLIC_ENDPOINT } from '../../../common/decorators/public-endpoint.decorator';
import { REQUIRED_PERMISSIONS } from '../decorators/require-permission.decorator';
import { PermissionRegistry } from '../permissions/permission-registry';

const ACCESS_DECLARATIONS = [IS_PUBLIC_ENDPOINT, IS_AUTHENTICATED_ONLY, REQUIRED_PERMISSIONS];

export interface ControllerClass {
  readonly name: string;
  readonly prototype: object;
}

/**
 * Finds route handlers that do not say how they are protected, or that require a permission
 * which is not in the catalogue. Returns one line per problem.
 */
export function findUndeclaredEndpoints(
  controllers: readonly ControllerClass[],
  reflector: Reflector = new Reflector(),
  scanner: MetadataScanner = new MetadataScanner(),
): string[] {
  const problems: string[] = [];
  for (const controller of controllers) {
    for (const methodName of scanner.getAllMethodNames(controller.prototype)) {
      const handler = (controller.prototype as Record<string, unknown>)[methodName];
      if (typeof handler !== 'function') continue;
      if (Reflect.getMetadata(PATH_METADATA, handler) === undefined) continue; // not a route

      const targets = [handler, controller as unknown as () => void];
      const declared = ACCESS_DECLARATIONS.some(
        (key) => reflector.getAllAndOverride<unknown>(key, targets) !== undefined,
      );
      if (!declared) {
        problems.push(`${controller.name}.${methodName}: no access declaration`);
        continue;
      }
      const required = reflector.getAllAndOverride<string[] | undefined>(
        REQUIRED_PERMISSIONS,
        targets,
      );
      for (const permission of required ?? []) {
        if (!PermissionRegistry.has(permission)) {
          problems.push(`${controller.name}.${methodName}: unknown permission "${permission}"`);
        }
      }
    }
  }
  return problems;
}

/**
 * Deny by default, checked before the first request: every HTTP endpoint must be marked
 * `@PublicEndpoint()`, `@AuthenticatedOnly()` or `@RequirePermission(...)`. A forgotten
 * declaration stops start-up instead of becoming an endpoint that is silently open or silently
 * closed (documentation/authorization.md §1).
 */
@Injectable()
export class EndpointAccessDeclarationCheck implements OnApplicationBootstrap {
  constructor(
    private readonly discovery: DiscoveryService,
    private readonly scanner: MetadataScanner,
    private readonly reflector: Reflector,
  ) {}

  onApplicationBootstrap(): void {
    const controllers = this.discovery
      .getControllers()
      .map((wrapper) => wrapper.metatype)
      .filter((metatype): metatype is ControllerClass & (new () => unknown) =>
        Boolean(metatype?.prototype),
      );
    const problems = findUndeclaredEndpoints(controllers, this.reflector, this.scanner);
    if (problems.length > 0) {
      throw new Error(
        `Endpoints without a valid access declaration (@PublicEndpoint, @AuthenticatedOnly or ` +
          `@RequirePermission):\n  - ${problems.join('\n  - ')}`,
      );
    }
  }
}
