import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter, type Types } from 'mongoose';
import { escapeRegExp } from '../../../common/pipes/list-query';
import {
  ONBOARDING_INVITATION_MODEL,
  type InvitationStatus,
  type OnboardingInvitation,
} from '../schemas/onboarding-invitation.schema';

export type StoredInvitation = OnboardingInvitation & { _id: Types.ObjectId };

/**
 * `onboarding_invitations`. Not tenant-scoped: invitations are handled by platform staff, and an
 * invited owner who has no account yet is looked up by the token alone.
 */
@Injectable()
export class InvitationRepository {
  constructor(
    @InjectModel(ONBOARDING_INVITATION_MODEL) private readonly model: Model<OnboardingInvitation>,
  ) {}

  findById(id: string | Types.ObjectId, session?: ClientSession): Promise<StoredInvitation | null> {
    return this.model
      .findById(id)
      .session(session ?? null)
      .lean<StoredInvitation>()
      .exec();
  }

  findByTokenHash(tokenHash: string, session?: ClientSession): Promise<StoredInvitation | null> {
    return this.model
      .findOne({ tokenHash })
      .session(session ?? null)
      .lean<StoredInvitation>()
      .exec();
  }

  async list(
    filter: {
      status?: InvitationStatus | undefined;
      createdAt?: { $gte?: Date; $lt?: Date } | undefined;
      /** Narrows pending invitations to valid (`$gte now`) or expired (`$lt now`) ones. */
      expiresAt?: { $gte?: Date; $lt?: Date } | undefined;
      search?: string | undefined;
    },
    page: { skip: number; limit: number },
  ): Promise<{ items: StoredInvitation[]; total: number }> {
    const match: QueryFilter<OnboardingInvitation> = {
      ...(filter.status ? { status: filter.status } : {}),
      ...(filter.createdAt ? { createdAt: filter.createdAt } : {}),
      ...(filter.expiresAt ? { expiresAt: filter.expiresAt } : {}),
      ...(filter.search
        ? {
            $or: ['companyName', 'ownerName', 'email'].map((field) => ({
              [field]: new RegExp(escapeRegExp(filter.search as string), 'i'),
            })),
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.model
        .find(match)
        .sort({ createdAt: -1 })
        .skip(page.skip)
        .limit(page.limit)
        .lean<StoredInvitation[]>()
        .exec(),
      this.model.countDocuments(match).exec(),
    ]);
    return { items, total };
  }

  async insert(
    invitation: OnboardingInvitation,
    session: ClientSession,
  ): Promise<StoredInvitation> {
    const [created] = await this.model.create([invitation], { session });
    if (!created) throw new Error('Invitation was not created');
    return created.toObject();
  }

  /** Changes an invitation that is still in `fromStatus`; null when it no longer is. */
  update(
    id: Types.ObjectId,
    fromStatus: InvitationStatus,
    set: Partial<OnboardingInvitation>,
    session?: ClientSession,
  ): Promise<StoredInvitation | null> {
    return this.model
      .findOneAndUpdate(
        { _id: id, status: fromStatus },
        { $set: set },
        { returnDocument: 'after', session: session ?? null, runValidators: true },
      )
      .lean<StoredInvitation>()
      .exec();
  }
}
