import { randomInt } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { normalizePhoneNumber } from '../../common/validation/contact-identifiers';
import { PasswordHasher } from '../authentication/services/password-hasher.service';
import { assertPasswordAcceptable } from '../authentication/services/password-policy';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { SessionsService } from '../sessions/services/sessions.service';
import { UsersService } from '../users/services/users.service';
import { type OperatorCrewDocument } from './crew_client_manage.service';

/*
 * The driver app login of a driver or conductor: made by the operator from the crew list. The
 * person signs in to the driver app with the phone number and a temporary password the operator
 * hands over (shown once), and chooses their own password at the first sign-in.
 */

export type CrewLoginState = 'NONE' | 'ACTIVE' | 'DISABLED';

export interface CrewLoginCredentials {
  /** What the person types in the "phone number" box of the driver app. */
  username: string;
  /** Shown once. Only an encrypted copy is stored. */
  temporaryPassword: string;
}

const PASSWORD_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
const PASSWORD_LENGTH = 12;
/** Crew roles that use the driver app, and the platform role each one gets. */
const ROLE_KEY_BY_CREW_ROLE: Readonly<Record<string, string>> = {
  DRIVER: 'DRIVER',
  CONDUCTOR: 'CONDUCTOR',
};

function generatePassword(): string {
  let password = '';
  for (let i = 0; i < PASSWORD_LENGTH; i++) {
    password += PASSWORD_ALPHABET.charAt(randomInt(PASSWORD_ALPHABET.length));
  }
  return password;
}

@Injectable()
export class CrewLoginClientManageService {
  constructor(
    @InjectModel('operator_crew') private readonly crew: Model<OperatorCrewDocument>,
    private readonly users: UsersService,
    private readonly hasher: PasswordHasher,
    private readonly roles: RoleRepository,
    private readonly sessions: SessionsService,
  ) {}

  private operatorOf(actor: AuthenticatedUserActor): Types.ObjectId {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator identification missing from session actor');
    }
    return new Types.ObjectId(actor.operatorId);
  }

  private async crewOf(actor: AuthenticatedUserActor, crewId: string): Promise<OperatorCrewDocument> {
    const found = Types.ObjectId.isValid(crewId)
      ? await this.crew
          .findOne({ _id: crewId, operatorId: this.operatorOf(actor), isDeleted: { $ne: true } })
          .exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record not found');
    return found;
  }

  /** A password the operator can read out, that passes the platform's password rules. */
  private async newTemporaryPassword(owner: { phone: string; name: string }): Promise<{
    plain: string;
    hash: string;
  }> {
    for (let attempt = 0; attempt < 10; attempt++) {
      const plain = generatePassword();
      try {
        assertPasswordAcceptable(plain, owner);
      } catch {
        continue;
      }
      return { plain, hash: await this.hasher.hash(plain) };
    }
    throw new Error('Could not generate a temporary password');
  }

  /** Whether each person has an app login, and whether it is switched on. */
  async statesFor(
    actor: AuthenticatedUserActor,
    crewIds: readonly string[],
  ): Promise<Map<string, CrewLoginState>> {
    const operatorId = this.operatorOf(actor);
    const result = new Map<string, CrewLoginState>();
    const linked = await this.crew
      .find({ _id: { $in: crewIds.map((id) => new Types.ObjectId(id)) }, operatorId })
      .select('userId')
      .lean()
      .exec();
    const links = new Map(linked.map((person) => [person._id.toHexString(), person.userId]));
    for (const id of crewIds) {
      const userId = links.get(id);
      const user = userId ? await this.users.findById(userId.toHexString()) : null;
      result.set(id, !user ? 'NONE' : user.status === 'ACTIVE' ? 'ACTIVE' : 'DISABLED');
    }
    return result;
  }

  /** A person removed from the crew list can no longer sign in to the driver app. */
  async switchOffForRemoved(actor: AuthenticatedUserActor, crewId: string): Promise<void> {
    const operatorId = this.operatorOf(actor);
    const person = await this.crew.findOne({ _id: crewId, operatorId }).select('userId').lean().exec();
    if (!person?.userId) return;
    const id = person.userId.toHexString();
    await this.users.setStatus(id, 'SUSPENDED');
    await this.sessions.revokeAllForUser(id, 'ACCOUNT_DISABLED');
  }

  async create(actor: AuthenticatedUserActor, crewId: string): Promise<CrewLoginCredentials> {
    const operatorId = this.operatorOf(actor);
    const person = await this.crewOf(actor, crewId);
    const roleKey = ROLE_KEY_BY_CREW_ROLE[person.role];
    if (!roleKey) {
      throw new ApiException('VALIDATION_FAILED', 'Only drivers and conductors sign in to the driver app.');
    }
    if (person.userId) {
      throw new ApiException('ALREADY_REGISTERED', 'This person already has a driver app login. Use "Reset password".');
    }
    const phone = normalizePhoneNumber(person.phone);
    if (!phone) {
      throw new ApiException('VALIDATION_FAILED', 'Add a valid mobile number for this person first.');
    }
    const role = await this.roles.findByKey(roleKey);
    if (!role) throw new ApiException('RESOURCE_NOT_FOUND', 'The driver role is not set up.');

    const password = await this.newTemporaryPassword({ phone, name: person.name });
    const existing = await this.users.findByPhone(phone);
    let userId: Types.ObjectId;
    if (existing) {
      // Only a driver account of this same operator can be taken over; anyone else's number stays theirs
      if (existing.userType !== 'DRIVER' || !existing.operatorId?.equals(operatorId)) {
        throw new ApiException('ALREADY_REGISTERED', 'This phone number already has an account in Abra.');
      }
      userId = existing._id;
      await this.users.setTemporaryPassword(userId.toHexString(), password.hash);
      await this.users.setStatus(userId.toHexString(), 'ACTIVE');
    } else {
      const created = await this.users.createDriver({
        name: person.name,
        phone,
        passwordHash: password.hash,
        roleIds: [role._id],
        operatorId,
      });
      userId = created._id;
    }
    await this.crew.updateOne({ _id: person._id }, { $set: { userId } }).exec();
    return { username: phone, temporaryPassword: password.plain };
  }

  async resetPassword(actor: AuthenticatedUserActor, crewId: string): Promise<CrewLoginCredentials> {
    const person = await this.crewOf(actor, crewId);
    if (!person.userId) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'This person has no driver app login yet.');
    }
    const user = await this.users.findById(person.userId.toHexString());
    if (!user?.phone) throw new ApiException('RESOURCE_NOT_FOUND', 'The driver app login was not found.');
    const password = await this.newTemporaryPassword({ phone: user.phone, name: person.name });
    await this.users.setTemporaryPassword(user._id.toHexString(), password.hash);
    // Anyone using the old password is signed out
    await this.sessions.revokeAllForUser(user._id.toHexString(), 'PASSWORD_CHANGED');
    return { username: user.phone, temporaryPassword: password.plain };
  }

  async setActive(
    actor: AuthenticatedUserActor,
    crewId: string,
    active: boolean,
  ): Promise<{ state: CrewLoginState }> {
    const person = await this.crewOf(actor, crewId);
    if (!person.userId) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'This person has no driver app login yet.');
    }
    const id = person.userId.toHexString();
    await this.users.setStatus(id, active ? 'ACTIVE' : 'SUSPENDED');
    if (!active) await this.sessions.revokeAllForUser(id, 'ACCOUNT_DISABLED');
    return { state: active ? 'ACTIVE' : 'DISABLED' };
  }
}
