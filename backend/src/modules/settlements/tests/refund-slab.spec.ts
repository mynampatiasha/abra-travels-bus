import {
  feeAndGst,
  refundPercent,
  roundPaise,
  FALLBACK_GST_PCT,
} from '../payout_cfg_admin_manage.service';

const slabs = [
  { hoursBefore: 48, refundPct: 100 },
  { hoursBefore: 24, refundPct: 75 },
  { hoursBefore: 12, refundPct: 50 },
  { hoursBefore: 4, refundPct: 25 },
  { hoursBefore: 0, refundPct: 0 },
];

describe('refundPercent', () => {
  it('no slabs at all means 100', () => {
    expect(refundPercent(10, [])).toBe(100);
  });

  it('takes the slab with the largest hoursBefore that is <= hours left', () => {
    expect(refundPercent(100, slabs)).toBe(100);
    expect(refundPercent(48, slabs)).toBe(100);
    expect(refundPercent(47.9, slabs)).toBe(75);
    expect(refundPercent(24, slabs)).toBe(75);
    expect(refundPercent(13, slabs)).toBe(50);
    expect(refundPercent(12, slabs)).toBe(50);
    expect(refundPercent(5, slabs)).toBe(25);
    expect(refundPercent(4, slabs)).toBe(25);
    expect(refundPercent(3.9, slabs)).toBe(0);
    expect(refundPercent(0, slabs)).toBe(0);
  });

  it('does not depend on the order of the slabs', () => {
    expect(refundPercent(30, [...slabs].reverse())).toBe(75);
  });

  it('no slab matches (no 0-hour slab and too late) means 0', () => {
    const noZero = slabs.filter((s) => s.hoursBefore !== 0);
    expect(refundPercent(2, noZero)).toBe(0);
    expect(refundPercent(-1, slabs)).toBe(0);
  });
});

describe('feeAndGst', () => {
  it('uses the saved rate on the fare and adds the saved fee (paise)', () => {
    const r = feeAndGst(100000, { gstPct: 18, convenienceFee: 4900 });
    expect(r.gst).toBe(18000);
    expect(r.convenienceFee).toBe(4900);
    expect(r.total).toBe(100000 + 18000 + 4900);
    expect(r.usedFallback).toBe(false);
  });

  it('rounds with the one rounding function and handles decimal rates', () => {
    expect(feeAndGst(999, { gstPct: 5.5, convenienceFee: 0 }).gst).toBe(
      roundPaise((999 * 550) / 10000),
    );
    expect(feeAndGst(1, { gstPct: 18, convenienceFee: 0 }).gst).toBe(0);
    expect(feeAndGst(3, { gstPct: 18, convenienceFee: 0 }).gst).toBe(1);
  });

  it('marks the fallback clearly when nothing is saved', () => {
    const r = feeAndGst(100000, null);
    expect(r.usedFallback).toBe(true);
    expect(r.gstPct).toBe(FALLBACK_GST_PCT);
  });

  it('rejects fares that are not whole paise', () => {
    expect(() => feeAndGst(10.5, { gstPct: 18, convenienceFee: 0 })).toThrow();
    expect(() => feeAndGst(-1, { gstPct: 18, convenienceFee: 0 })).toThrow();
  });
});
