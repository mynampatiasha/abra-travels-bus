import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import {
  ONBOARDING_SUBMISSION_MODEL,
  type OnboardingSubmission,
} from '../schemas/onboarding-submission.schema';

export type StoredSubmission = StoredDocument<OnboardingSubmission>;

/** `onboarding_submissions`, restricted to the operators in the actor's data scope. */
@Injectable()
export class SubmissionRepository extends ScopedRepository<OnboardingSubmission> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(ONBOARDING_SUBMISSION_MODEL) model: Model<OnboardingSubmission>) {
    super(model);
  }

  /**
   * Saves a change to a submission read earlier, only if nobody changed it in between (its
   * `updatedAt` is still the one that was read). Otherwise two people editing at once could
   * overwrite each other's documents or a reviewer's decision.
   */
  async saveChange(
    before: StoredSubmission,
    set: Partial<OnboardingSubmission>,
    session: ClientSession,
    unset: ReadonlyArray<keyof OnboardingSubmission> = [],
  ): Promise<StoredSubmission> {
    const saved = await this.findOneAndUpdate(
      { _id: before._id, updatedAt: before.updatedAt },
      {
        $set: set,
        ...(unset.length > 0
          ? { $unset: Object.fromEntries(unset.map((field) => [field, ''])) }
          : {}),
      },
      { session },
    );
    if (!saved) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This submission was changed by someone else. Reload it and try again.',
      );
    }
    return saved;
  }
}
