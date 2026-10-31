import { type Connection, type Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { BUS_DOC_LABELS, REQUIRED_BUS_DOC_TYPES, type BusDocType } from '../buses/bus_documents_client_manage.service';

/**
 * A trip cannot go on sale when a required document of its bus (RC, insurance, permit, fitness) ends
 * before the trip leaves. A bus with no document of a kind is not stopped here: only a document that has
 * expired is. If the owner added a renewed copy, the latest date counts.
 */
export async function assertBusDocumentsValid(
  connection: Connection,
  bus: { _id: Types.ObjectId; registrationNumber?: string | undefined },
  departureAt: Date,
): Promise<void> {
  const docs = await connection
    .collection<{ docType: BusDocType; docName: string; validTill: Date }>('bus_documents')
    .find({ busId: bus._id, isDeleted: { $ne: true }, docType: { $in: [...REQUIRED_BUS_DOC_TYPES] } } as object)
    .toArray();
  for (const type of REQUIRED_BUS_DOC_TYPES) {
    const ofType = docs.filter((doc) => doc.docType === type);
    if (ofType.length === 0) continue;
    const latest = ofType.reduce((a, b) => (new Date(a.validTill) >= new Date(b.validTill) ? a : b));
    const endsOn = new Date(latest.validTill);
    // A document valid through the departure day still covers the trip
    if (endsOn.getTime() + 24 * 60 * 60 * 1000 <= departureAt.getTime()) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `The ${BUS_DOC_LABELS[type]} of bus ${bus.registrationNumber ?? ''} ended on ${endsOn.toISOString().slice(0, 10)}, before this trip. Renew it first.`.replace('bus  ', 'bus '),
      );
    }
  }
}
