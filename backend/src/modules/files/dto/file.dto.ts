import { z } from 'zod';
import { objectIdString } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';

/** The text fields sent next to the file in the multipart upload. */
export class UploadFileDto extends createZodDto(
  z.object({
    /** What the file is: a document type from the required-documents list. */
    documentTypeId: objectIdString,
    /**
     * The operator the file belongs to. Operator staff leave it out (it is their own operator);
     * platform staff uploading on an operator's behalf must give it.
     */
    operatorId: objectIdString.optional(),
  }),
) {}

export class FileIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}
