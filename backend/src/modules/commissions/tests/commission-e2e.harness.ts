import { Types } from 'mongoose';
import { type Response } from 'supertest';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import { type CommissionRuleView, todayIst } from '../commission_admin_manage.service';

/** Shared set-up of the commission end-to-end suites: the app, three people and some records to point rules at. */
export type Caller = SeededUser & { tokens: Tokens };

export const API = '/api/v1/admin/commission';
const DAY_MS = 24 * 60 * 60 * 1000;
const OWN_COLLECTIONS = [
  'commission_rules',
  'commission_history',
  'commission_default',
  'payout_settings',
];

export function binary(response: Response, callback: (error: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  response.on('data', (chunk: Buffer) => chunks.push(chunk));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
}

/** Days from today in India time, as `YYYY-MM-DD`. */
export function inDays(days: number): string {
  return todayIst(new Date(Date.now() + days * DAY_MS));
}

export interface CommissionFixture {
  context: AuthTestContext;
  superAdmin: Caller;
  admin: Caller;
  support: Caller;
  operator: { id: Types.ObjectId; name: string };
  otherOperator: { id: Types.ObjectId; name: string };
  route: { id: Types.ObjectId; name: string };
  busType: { id: Types.ObjectId; name: string };
  send: (
    who: Caller,
    method: 'get' | 'post' | 'put' | 'patch' | 'delete',
    path: string,
    body?: object,
  ) => ReturnType<ReturnType<typeof client>['get']>;
  rule: (overrides?: Record<string, unknown>) => Record<string, unknown>;
  created: (overrides?: Record<string, unknown>) => Promise<CommissionRuleView>;
  calculate: (body?: Record<string, unknown>) => ReturnType<CommissionFixture['send']>;
  resetRules: () => Promise<void>;
}

/** Registers the set-up and clean-up of one suite and returns what the tests use. */
export function commissionFixture(): CommissionFixture {
  const fx = {
    operator: { id: new Types.ObjectId(), name: 'Kaveri Express' },
    otherOperator: { id: new Types.ObjectId(), name: 'Godavari Lines' },
    route: { id: new Types.ObjectId(), name: 'Hyderabad to Bengaluru' },
    busType: { id: new Types.ObjectId(), name: 'AC Sleeper' },
  } as CommissionFixture;

  fx.send = (who, method, path, body) => {
    const request = client(fx.context)
      [method](`${API}${path}`)
      .set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };
  fx.rule = (overrides = {}) => ({
    scope: 'OPERATOR',
    targetId: fx.operator.id.toHexString(),
    mode: 'PERCENT',
    value: 1200,
    effectiveFrom: todayIst(),
    agreedNote: 'Agreed on a call',
    ...overrides,
  });
  fx.created = async (overrides = {}) =>
    dataOf<CommissionRuleView>(
      await fx.send(fx.superAdmin, 'post', '/rules', fx.rule(overrides)).expect(201),
    );
  fx.calculate = (body = {}) =>
    fx.send(fx.superAdmin, 'post', '/calculate', {
      farePerSeatPaise: 120_000,
      seats: 2,
      operatorId: fx.operator.id.toHexString(),
      ...body,
    });
  fx.resetRules = async () => {
    for (const name of ['commission_rules', 'commission_history']) {
      await fx.context.connection.collection(name).deleteMany({});
    }
  };

  const signIn = (roleKey: SystemRoleKey) => seedAndSignIn(fx.context, { roleKeys: [roleKey] });

  beforeAll(async () => {
    fx.context = await createAuthTestApp();
    for (const name of OWN_COLLECTIONS) {
      await fx.context.connection.collection(name).deleteMany({});
    }
    await fx.context.connection.collection('operators').insertMany([
      { _id: fx.operator.id, companyName: fx.operator.name, status: 'ACTIVE' },
      { _id: fx.otherOperator.id, companyName: fx.otherOperator.name, status: 'ACTIVE' },
    ]);
    await fx.context.connection
      .collection('routes')
      .insertOne({ _id: fx.route.id, name: fx.route.name });
    await fx.context.connection
      .collection('bus_types')
      .insertOne({ _id: fx.busType.id, name: fx.busType.name });
    fx.superAdmin = await signIn('SUPER_ADMIN');
    fx.admin = await signIn('ADMIN');
    fx.support = await signIn('SUPPORT');
  }, 120_000);

  afterAll(async () => {
    for (const name of OWN_COLLECTIONS) {
      await fx.context.connection.collection(name).deleteMany({});
    }
    await fx.context.connection
      .collection('operators')
      .deleteMany({ _id: { $in: [fx.operator.id, fx.otherOperator.id] } });
    await fx.context.connection.collection('routes').deleteOne({ _id: fx.route.id });
    await fx.context.connection.collection('bus_types').deleteOne({ _id: fx.busType.id });
    await fx.context.close();
  }, 60_000);

  return fx;
}
