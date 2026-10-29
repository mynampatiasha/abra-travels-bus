/*
 * What a customer pays for a booking. The one place for the tax and the fee: the server decides,
 * the app only shows an estimate with the same numbers. A change here is a change everywhere.
 */

/** GST on the base fare, in percent. */
export const GST_PERCENT = 5;

/** A flat fee for each booking, in paise (Rs 49). Not taxed. */
export const CONVENIENCE_FEE_PAISE = 4900;

export interface FareBreakup {
  baseFarePaise: number;
  gstPaise: number;
  convenienceFeePaise: number;
  discountPaise: number;
  /** base + GST + fee - discount. */
  amountPaise: number;
}

/** 5% of the base fare, to the nearest paisa (half up). */
export function gstOf(baseFarePaise: number): number {
  return Math.floor((baseFarePaise * GST_PERCENT + 50) / 100);
}

/** The discount never goes above the base fare, so the total is never below the tax and the fee. */
export function computeFare(baseFarePaise: number, discountPaise = 0): FareBreakup {
  const discount = Math.max(0, Math.min(discountPaise, baseFarePaise));
  const gstPaise = gstOf(baseFarePaise);
  const convenienceFeePaise = baseFarePaise === 0 ? 0 : CONVENIENCE_FEE_PAISE;
  return {
    baseFarePaise,
    gstPaise,
    convenienceFeePaise,
    discountPaise: discount,
    amountPaise: baseFarePaise + gstPaise + convenienceFeePaise - discount,
  };
}
