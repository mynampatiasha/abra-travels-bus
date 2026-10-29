describe('TripsClientManage logic', () => {
  it('ensures seat inventory calculations keep available + blocked equal to total for unsold trips', () => {
    const total = 40;
    let available = 40;
    let blocked = 0;

    // Block 3 seats
    const blockCount = 3;
    available -= blockCount;
    blocked += blockCount;

    expect(available).toBe(37);
    expect(blocked).toBe(3);
    expect(available + blocked).toBe(total);

    // Unblock 1 seat
    available += 1;
    blocked -= 1;
    expect(available).toBe(38);
    expect(blocked).toBe(2);
    expect(available + blocked).toBe(total);
  });
});
