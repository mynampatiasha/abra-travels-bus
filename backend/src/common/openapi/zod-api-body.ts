import { applyDecorators } from '@nestjs/common';
import { ApiBody } from '@nestjs/swagger';
import { z } from 'zod';
import { type ZodDtoClass } from '../pipes/zod-validation.pipe';

/**
 * Documents a zod DTO as the request body in OpenAPI. The JSON schema is generated from the same
 * zod schema that validates the request, so documentation and validation cannot drift.
 */
export function ZodApiBody(dto: ZodDtoClass): MethodDecorator {
  const jsonSchema = z.toJSONSchema(dto.zodSchema, { io: 'input', unrepresentable: 'any' });
  // OpenAPI embeds the schema; the JSON-Schema dialect marker does not belong there
  const schema = Object.fromEntries(
    Object.entries(jsonSchema).filter(([key]) => key !== '$schema'),
  );
  return applyDecorators(ApiBody({ schema }));
}
