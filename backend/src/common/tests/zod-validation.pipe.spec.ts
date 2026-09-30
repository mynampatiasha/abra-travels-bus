import { z } from 'zod';
import { ApiException } from '../errors/api-exception';
import { createZodDto } from '../pipes/zod-dto.factory';
import { ZodValidationPipe } from '../pipes/zod-validation.pipe';

class ExampleDto extends createZodDto(
  z.object({ name: z.string().min(1), seats: z.coerce.number().int().positive() }),
) {}

describe('ZodValidationPipe', () => {
  const pipe = new ZodValidationPipe();

  it('returns the parsed value for a valid DTO', () => {
    expect(
      pipe.transform({ name: 'A', seats: '2' }, { type: 'body', metatype: ExampleDto }),
    ).toEqual({ name: 'A', seats: 2 });
  });

  it('rejects unknown fields and invalid values with VALIDATION_FAILED details', () => {
    let thrown: unknown;
    try {
      pipe.transform({ name: '', seats: 1, extra: true }, { type: 'body', metatype: ExampleDto });
    } catch (error) {
      thrown = error;
    }
    expect(thrown).toBeInstanceOf(ApiException);
    const exception = thrown as ApiException;
    expect(exception.code).toBe('VALIDATION_FAILED');
    expect(exception.status).toBe(400);
    const issues = (exception.details?.issues ?? []) as Array<{ path: string; code: string }>;
    expect(issues.map((issue) => issue.code)).toEqual(
      expect.arrayContaining(['too_small', 'unrecognized_keys']),
    );
  });

  it('leaves parameters without a zod DTO untouched', () => {
    expect(pipe.transform('abc', { type: 'param', metatype: String })).toBe('abc');
  });
});
