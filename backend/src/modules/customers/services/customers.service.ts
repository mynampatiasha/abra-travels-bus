import { Injectable } from '@nestjs/common';
import { type ClientSession, type Types } from 'mongoose';
import { CustomerRepository, type StoredCustomer } from '../repositories/customer.repository';

@Injectable()
export class CustomersService {
  constructor(private readonly repository: CustomerRepository) {}

  /** Creates the profile in the same transaction as its user, so neither exists without the other. */
  createForUser(
    userId: Types.ObjectId,
    options: { marketingConsent: boolean },
    session: ClientSession,
  ): Promise<StoredCustomer> {
    return this.repository.insert(
      {
        userId,
        marketingConsent: { granted: options.marketingConsent, at: new Date() },
        notificationPreferences: {
          email: true,
          sms: true,
          whatsapp: true,
          push: true,
          marketing: options.marketingConsent,
        },
      },
      session,
    );
  }

  findByUserId(userId: string): Promise<StoredCustomer | null> {
    return this.repository.findByUserId(userId);
  }
}
