import { CONVENIENCE_FEE_PAISE, computeFare, gstOf } from '../booking_pricing';

describe('booking pricing', () => {
  it('adds 5% GST and the flat fee to the base fare', () => {
    expect(computeFare(85_000)).toEqual({
      baseFarePaise: 85_000,
      gstPaise: 4_250,
      convenienceFeePaise: CONVENIENCE_FEE_PAISE,
      discountPaise: 0,
      amountPaise: 94_150,
    });
  });

  it('rounds GST to the nearest paisa, half up', () => {
    expect(gstOf(10)).toBe(1);
    expect(gstOf(9)).toBe(0);
    expect(gstOf(11)).toBe(1);
    expect(gstOf(30)).toBe(2);
  });

  it('takes the discount off the total but never above the base fare', () => {
    expect(computeFare(85_000, 10_000).amountPaise).toBe(84_150);
    expect(computeFare(85_000, 999_999)).toMatchObject({ discountPaise: 85_000, amountPaise: 9_150 });
    expect(computeFare(85_000, -5).discountPaise).toBe(0);
  });

  it('charges nothing for an empty booking', () => {
    expect(computeFare(0).amountPaise).toBe(0);
  });
});
