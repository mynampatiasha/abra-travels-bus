import { type ArgumentMetadata, Injectable, type PipeTransform } from '@nestjs/common';
import { type ZodType } from 'zod';
import { ApiException } from '../errors/api-exception';

/** A DTO class created by `createZodDto` carries its schema as a static property. */
export interface ZodDtoClass {
  readonly zodSchema: ZodType;
}

function isZodDtoClass(metatype: unknown): metatype is ZodDtoClass {
  return typeof metatype === 'function' && 'zodSchema' in metatype;
}

/**
 * Global validation (api-architecture.md §1: "validation with zod DTOs; unknown fields rejected").
 * Every body, query and param typed with a `createZodDto` class is parsed; the parsed (coerced,
 * stripped of nothing — schemas are strict) value replaces the raw input.
 * Parameters typed with plain primitives are left alone.
 */
@Injectable()
export class ZodValidationPipe implements PipeTransform {
  transform(value: unknown, metadata: ArgumentMetadata): unknown {
    if (!isZodDtoClass(metadata.metatype)) return value;

    const result = metadata.metatype.zodSchema.safeParse(value);
    if (result.success) return result.data;

    throw new ApiException('VALIDATION_FAILED', 'Request validation failed', {
      location: metadata.type,
      issues: result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        code: issue.code,
        message: issue.message,
      })),
    });
  }
}
