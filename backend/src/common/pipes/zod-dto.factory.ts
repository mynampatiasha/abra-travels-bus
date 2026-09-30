import { z, type ZodObject, type ZodRawShape } from 'zod';

/**
 * Builds a DTO class from a zod object schema. The schema is made strict, so unknown fields are
 * rejected with VALIDATION_FAILED instead of silently passing through.
 *
 *   export class CancelBookingDto extends createZodDto(z.object({ bookingSeatIds: z.array(z.string()) })) {}
 */
export function createZodDto<Shape extends ZodRawShape>(schema: ZodObject<Shape>) {
  const strictSchema = schema.strict();

  class ZodDto {
    static readonly zodSchema = strictSchema;
  }

  return ZodDto as unknown as {
    new (): z.output<typeof strictSchema>;
    readonly zodSchema: typeof strictSchema;
  };
}
