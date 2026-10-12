import { Injectable } from '@nestjs/common';
import { ApiException } from '../../common/errors/api-exception';
import { BusTypeRepository } from './repositories/bus-type.repository';
import { type BusTypeView, busTypeViewOf } from './services/bus-types.service';

/** Reading one bus type for the detail window of the admin page. */
@Injectable()
export class BusTypesManageService {
  constructor(private readonly busTypes: BusTypeRepository) {}

  async get(id: string): Promise<BusTypeView> {
    const found = await this.busTypes.findById(id);
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Bus type not found');
    return busTypeViewOf(found);
  }
}
