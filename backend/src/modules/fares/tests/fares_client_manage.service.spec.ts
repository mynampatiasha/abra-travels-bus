import { calculateCustomerPays } from '../fares_client_manage.service';

describe('FaresClientManageService logic', () => {
  it('calculates customer pays correctly with commission, GST and fee in integer paise', () => {
    const fare = 100000; // Rs 1000 in paise
    const res = calculateCustomerPays(fare);
    expect(res.fare).toBe(100000);
    expect(res.cm).toBe(8000); // 8% commission
    expect(res.gst).toBe(5400); // 5% of (100000 + 8000)
    expect(res.fee).toBe(500); // Rs 5 fee
    expect(res.total).toBe(113900); // 100000 + 8000 + 5400 + 500
  });

  it('handles minimum fare of Rs 100', () => {
    const res = calculateCustomerPays(10000); // Rs 100
    expect(res.fare).toBe(10000);
    expect(res.cm).toBe(800);
    expect(res.gst).toBe(540);
    expect(res.fee).toBe(500);
    expect(res.total).toBe(11840);
  });
});
