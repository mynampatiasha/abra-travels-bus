import { Types } from 'mongoose';
import {
  type CommissionVersion,
  checkCommission,
  computePrice,
  formatCommission,
  isValidDay,
  todayIst,
  versionInEffect,
} from '../commission_admin_manage.service';

const version = (
  number: number,
  effectiveFrom: string,
  value = number * 100,
): CommissionVersion => ({
  version: number,
  mode: 'PERCENT',
  value,
  effectiveFrom,
  agreedNote: '',
  createdAt: new Date('2026-01-01T00:00:00Z'),
  createdBy: new Types.ObjectId(),
});

describe('Commission price', () => {
  const fees = { gstPct: 18, convenienceFeePaise: 4900 };

  it('adds a percentage on top of the operator fare, rounded once on all seats', () => {
    // Rs 1,200 x 2 seats at 10%
    const price = computePrice({
      farePerSeatPaise: 120_000,
      seats: 2,
      mode: 'PERCENT',
      value: 1000,
      ...fees,
    });
    expect(price).toEqual({
      operatorFare: 240_000,
      commission: 24_000,
      fareShown: 264_000,
      gst: 47_520,
      convenienceFee: 4900,
      customerPays: 316_420,
      operatorReceives: 240_000,
    });
  });

  it('a flat commission is the value for every seat', () => {
    const price = computePrice({
      farePerSeatPaise: 100_000,
      seats: 3,
      mode: 'FLAT',
      value: 6000,
      gstPct: 5,
      convenienceFeePaise: 0,
    });
    expect(price.commission).toBe(18_000);
    expect(price.fareShown).toBe(318_000);
    expect(price.gst).toBe(15_900);
    expect(price.customerPays).toBe(333_900);
  });

  it('the operator always receives exactly the fare they set', () => {
    for (const seats of [1, 4, 6]) {
      const price = computePrice({
        farePerSeatPaise: 99_901,
        seats,
        mode: 'PERCENT',
        value: 1234,
        ...fees,
      });
      expect(price.operatorReceives).toBe(99_901 * seats);
      expect(price.customerPays).toBe(price.fareShown + price.gst + price.convenienceFee);
    }
  });

  it('rounds half a paisa up, once', () => {
    // 15 paise at 10% is 1.5: one rounding on the whole fare, not per seat
    const price = computePrice({
      farePerSeatPaise: 15,
      seats: 1,
      mode: 'PERCENT',
      value: 1000,
      gstPct: 0,
      convenienceFeePaise: 0,
    });
    expect(price.commission).toBe(2);
  });
});

describe('Commission values', () => {
  it('a percentage is 0 to 40, flat is any whole amount from zero', () => {
    expect(checkCommission('PERCENT', 4000)).toEqual({ mode: 'PERCENT', value: 4000 });
    expect(checkCommission('PERCENT', 0)).toEqual({ mode: 'PERCENT', value: 0 });
    expect(checkCommission('FLAT', 150_000)).toEqual({ mode: 'FLAT', value: 150_000 });
    expect(() => checkCommission('PERCENT', 4001)).toThrow('Request validation failed');
    expect(() => checkCommission('FLAT', -1)).toThrow();
    expect(() => checkCommission('FLAT', 1.5)).toThrow();
  });

  it('shows 10% and Rs 60 per seat the way the table does', () => {
    expect(formatCommission('PERCENT', 1000)).toBe('10%');
    expect(formatCommission('PERCENT', 1250)).toBe('12.5%');
    expect(formatCommission('FLAT', 6000)).toBe('Rs 60 per seat');
  });
});

describe('Versions and dates', () => {
  it('uses the version in force on the day: a version dated next week waits', () => {
    const versions = [version(1, '2026-10-01'), version(2, '2026-10-20')];
    expect(versionInEffect(versions, '2026-09-30')).toBeUndefined();
    expect(versionInEffect(versions, '2026-10-01')?.version).toBe(1);
    expect(versionInEffect(versions, '2026-10-19')?.version).toBe(1);
    expect(versionInEffect(versions, '2026-10-20')?.version).toBe(2);
  });

  it('two versions that start on the same day: the later one wins', () => {
    const versions = [version(1, '2026-10-01'), version(2, '2026-10-01')];
    expect(versionInEffect(versions, '2026-10-05')?.version).toBe(2);
  });

  it('works out today in India time', () => {
    // 20:00 UTC is already the next day in India (+5:30)
    expect(todayIst(new Date('2026-10-13T20:00:00Z'))).toBe('2026-10-14');
    expect(todayIst(new Date('2026-10-13T10:00:00Z'))).toBe('2026-10-13');
  });

  it('knows a real calendar day from a made-up one', () => {
    expect(isValidDay('2026-02-28')).toBe(true);
    expect(isValidDay('2026-02-30')).toBe(false);
    expect(isValidDay('26-02-28')).toBe(false);
    expect(isValidDay(20_260_228)).toBe(false);
  });
});
