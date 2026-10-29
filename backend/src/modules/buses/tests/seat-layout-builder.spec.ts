import {
  defaultSeatMap,
  parseSeatMapToSeats,
} from '../buses_client_manage.service';

describe('SeatLayoutBuilder', () => {
  describe('defaultSeatMap', () => {
    it('generates 4-seat rows for 2+2 Seater', () => {
      const map = defaultSeatMap('2+2 Seater', 40);
      expect(map.length).toBe(10);
      expect(map[0]).toBe('SS_SS');
    });

    it('generates 3-seat rows for 2+1 Sleeper', () => {
      const map = defaultSeatMap('2+1 Sleeper', 30);
      expect(map.length).toBe(10);
      expect(map[0]).toBe('SS_S');
    });
  });

  describe('parseSeatMapToSeats', () => {
    it('parses single deck seater map correctly', () => {
      const lower = ['SS_SS', 'SL_SS'];
      const parsed = parseSeatMapToSeats(lower);

      expect(parsed.totalSeats).toBe(8);
      expect(parsed.ladiesSeatsCount).toBe(1);
      expect(parsed.berthCount).toBe(0);

      // Check ladies seat
      const ladiesSeat = parsed.seats.find((s) => s.isLadies);
      expect(ladiesSeat).toBeDefined();
      expect(ladiesSeat?.seatNumber).toBe('6');
      expect(ladiesSeat?.row).toBe(1);
      expect(ladiesSeat?.col).toBe(1);
    });

    it('parses double deck layout with sleeper berths correctly', () => {
      const lower = ['BB_B', 'BB_B'];
      const upper = ['BB_B', 'BB_B'];
      const parsed = parseSeatMapToSeats(lower, upper);

      expect(parsed.totalSeats).toBe(12);
      expect(parsed.berthCount).toBe(12);

      // First lower berth
      expect(parsed.seats[0]?.seatNumber).toBe('L1');
      expect(parsed.seats[0]?.deck).toBe(1);
      expect(parsed.seats[0]?.type).toBe('SLEEPER');
      expect(parsed.seats[0]?.category).toBe('PREMIUM');

      // First upper berth
      const firstUpper = parsed.seats.find((s) => s.deck === 2);
      expect(firstUpper?.seatNumber).toBe('U1');
      expect(firstUpper?.type).toBe('SLEEPER');
    });
  });
});
