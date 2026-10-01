import { randomUUID } from 'node:crypto';
import { Injectable, type OnModuleInit } from '@nestjs/common';
import { errors, importPKCS8, importSPKI, jwtVerify, SignJWT } from 'jose';
import { ApiException } from '../../../common/errors/api-exception';
import { type UserType } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import { USER_TYPES } from '../../users/schemas/user.schema';

export interface AccessTokenSubject {
  userId: string;
  userType: UserType;
  sessionId: string;
  permissionVersion: number;
  operatorId?: string;
}

export interface IssuedAccessToken {
  token: string;
  expiresInSeconds: number;
}

export interface MfaChallenge {
  userId: string;
  /** Unique id of this challenge token; used to make it single-use. */
  challengeId: string;
  expiresInSeconds: number;
}

type SigningKey = CryptoKey | Uint8Array;

interface KeyMaterial {
  algorithm: 'RS256' | 'HS256';
  signingKey: SigningKey;
  verificationKey: SigningKey;
}

const ACCESS_TOKEN_TYPE = 'at+jwt';
const MFA_CHALLENGE_TYPE = 'mfa+jwt';
const CLOCK_TOLERANCE_SECONDS = 5;

function unauthenticated(): ApiException {
  return new ApiException('UNAUTHENTICATED', 'Authentication is required');
}

/**
 * Signs and verifies access tokens (authentication.md §2): short-lived JWTs carrying only
 * `sub` (user id), `typ` (user type), `sid` (session id), `pv` (permission version) and `op`
 * (operator id). No names, contact details, roles or permissions.
 *
 * RS256 with a key pair in staging and production, HS256 with JWT_ACCESS_SECRET in development
 * and test (enforced by configuration validation). The algorithm is pinned on verification, so a
 * token signed with any other algorithm — including "none" — is rejected.
 */
@Injectable()
export class AccessTokenService implements OnModuleInit {
  private keyMaterial: Promise<KeyMaterial> | undefined;

  constructor(private readonly config: AppConfigService) {}

  /**
   * Loads and validates the signing keys at start-up, so a malformed production key stops the
   * process immediately instead of passing readiness and failing every sign-in later.
   */
  async onModuleInit(): Promise<void> {
    await this.keys();
  }

  async issue(subject: AccessTokenSubject): Promise<IssuedAccessToken> {
    const { algorithm, signingKey } = await this.keys();
    const expiresInSeconds = this.config.get('JWT_ACCESS_TTL_SECONDS');
    const token = await new SignJWT({
      typ: subject.userType,
      sid: subject.sessionId,
      pv: subject.permissionVersion,
      ...(subject.operatorId ? { op: subject.operatorId } : {}),
    })
      .setProtectedHeader({ alg: algorithm, typ: ACCESS_TOKEN_TYPE })
      .setSubject(subject.userId)
      .setIssuer(this.config.get('JWT_ISSUER'))
      .setAudience(this.config.get('JWT_AUDIENCE'))
      .setIssuedAt()
      .setExpirationTime(`${expiresInSeconds}s`)
      .sign(signingKey);
    return { token, expiresInSeconds };
  }

  /** Throws TOKEN_EXPIRED for an expired token and UNAUTHENTICATED for anything else invalid. */
  async verify(token: string): Promise<AccessTokenSubject> {
    const payload = await this.verifyToken(
      token,
      ACCESS_TOKEN_TYPE,
      this.config.get('JWT_AUDIENCE'),
    );
    const { sub, typ, sid, pv, op } = payload;
    const userType = USER_TYPES.find((candidate) => candidate === typ);
    if (!sub || !userType || typeof sid !== 'string' || typeof pv !== 'number') {
      throw unauthenticated();
    }
    return {
      userId: sub,
      userType,
      sessionId: sid,
      permissionVersion: pv,
      ...(typeof op === 'string' ? { operatorId: op } : {}),
    };
  }

  /**
   * Links a correct password to the second-factor step. It is not an access token: different
   * type and audience, so it can never authenticate an API request.
   */
  async issueMfaChallenge(userId: string): Promise<{ token: string; expiresInSeconds: number }> {
    const { algorithm, signingKey } = await this.keys();
    const expiresInSeconds = this.config.get('MFA_CHALLENGE_TTL_SECONDS');
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: algorithm, typ: MFA_CHALLENGE_TYPE })
      .setSubject(userId)
      .setJti(randomUUID())
      .setIssuer(this.config.get('JWT_ISSUER'))
      .setAudience(this.mfaAudience())
      .setIssuedAt()
      .setExpirationTime(`${expiresInSeconds}s`)
      .sign(signingKey);
    return { token, expiresInSeconds };
  }

  /** Throws MFA_INVALID for an expired, malformed or foreign challenge token. */
  async verifyMfaChallenge(token: string): Promise<MfaChallenge> {
    try {
      const payload = await this.verifyToken(token, MFA_CHALLENGE_TYPE, this.mfaAudience());
      if (!payload.sub || !payload.jti || !payload.exp) throw unauthenticated();
      return {
        userId: payload.sub,
        challengeId: payload.jti,
        expiresInSeconds: Math.max(1, payload.exp - Math.floor(Date.now() / 1000)),
      };
    } catch {
      throw new ApiException(
        'MFA_INVALID',
        'The verification step has expired. Please sign in again.',
      );
    }
  }

  private mfaAudience(): string {
    return `${this.config.get('JWT_AUDIENCE')}:mfa`;
  }

  private async verifyToken(token: string, type: string, audience: string) {
    const { algorithm, verificationKey } = await this.keys();
    try {
      const { payload } = await jwtVerify(token, verificationKey, {
        algorithms: [algorithm],
        issuer: this.config.get('JWT_ISSUER'),
        audience,
        typ: type,
        clockTolerance: CLOCK_TOLERANCE_SECONDS,
        requiredClaims: ['sub', 'exp', 'iat'],
      });
      return payload;
    } catch (error) {
      if (error instanceof errors.JWTExpired) {
        throw new ApiException('TOKEN_EXPIRED', 'The access token has expired');
      }
      throw unauthenticated();
    }
  }

  private keys(): Promise<KeyMaterial> {
    this.keyMaterial ??= this.loadKeys();
    return this.keyMaterial;
  }

  private async loadKeys(): Promise<KeyMaterial> {
    const privateKey = this.config.get('JWT_ACCESS_PRIVATE_KEY');
    const publicKey = this.config.get('JWT_ACCESS_PUBLIC_KEY');
    if (privateKey && publicKey) {
      // Secret managers often store PEM newlines as the two characters "\n"
      const pem = (value: string): string => value.replace(/\\n/g, '\n');
      return {
        algorithm: 'RS256',
        signingKey: await importPKCS8(pem(privateKey), 'RS256'),
        verificationKey: await importSPKI(pem(publicKey), 'RS256'),
      };
    }
    const secret = this.config.get('JWT_ACCESS_SECRET');
    if (!secret) throw new Error('No access-token signing key is configured');
    const key = new TextEncoder().encode(secret);
    return { algorithm: 'HS256', signingKey: key, verificationKey: key };
  }
}
