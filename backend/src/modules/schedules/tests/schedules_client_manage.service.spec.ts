import { WEEKDAYS } from '../schedules_client_manage.service';

describe('SchedulesClientManageService logic', () => {
  it('defines 7 weekdays starting from Monday', () => {
    expect(WEEKDAYS).toEqual(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
  });

  it('correctly maps date day of week to weekday names', () => {
    // 2026-10-21 is a Wednesday
    const d = new Date('2026-10-21T12:00:00Z');
    const dayIndex = (d.getDay() + 6) % 7; // Monday is 0, Wednesday is 2
    expect(WEEKDAYS[dayIndex]).toBe('Wed');
  });
});
