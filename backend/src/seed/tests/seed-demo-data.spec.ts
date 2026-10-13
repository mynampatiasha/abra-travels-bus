import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { model, Types } from 'mongoose';
import { busTypeSchema } from '../../modules/bus-types/schemas/bus-type.schema';
import { busSchema } from '../../modules/buses/schemas/bus.schema';
import { citySchema } from '../../modules/cities/schemas/city.schema';
import { locationSchema } from '../../modules/locations/schemas/location.schema';
import { operatorSchema } from '../../modules/operators/schemas/operator.schema';
import {
  busOf,
  busTypeOf,
  cityOf,
  type DemoData,
  locationOf,
  operatorOf,
  pointOf,
  slugOf,
} from '../seed-demo-data.service';

const data = JSON.parse(
  readFileSync(join(__dirname, '../../../seed/demo-data.json'), 'utf8'),
) as DemoData;

// Models are only used to check documents against the real schemas; nothing connects
const City = model('SeedCityCheck', citySchema);
const Location = model('SeedLocationCheck', locationSchema);
const BusType = model('SeedBusTypeCheck', busTypeSchema);
const Operator = model('SeedOperatorCheck', operatorSchema);
const Bus = model('SeedBusCheck', busSchema);

const problems = (document: { validateSync(): { message: string } | null }): string =>
  document.validateSync()?.message ?? '';

describe('the demo fixture', () => {
  it('has the sample data of the demos', () => {
    expect(data.cities).toHaveLength(20);
    expect(data.places).toHaveLength(52);
    expect(data.busTypes).toHaveLength(6);
    expect(data.operators).toHaveLength(14);
    expect(data.buses).toHaveLength(31);
  });

  it('names no secret and no personal data beyond sample companies', () => {
    const text = JSON.stringify(data);
    expect(text).not.toMatch(/password|secret|token|api[_-]?key/i);
  });
});

describe('slugOf', () => {
  it.each([
    ['Hyderabad', 'hyderabad'],
    ['Visakhapatnam', 'visakhapatnam'],
    ['  New  Delhi!  ', 'new-delhi'],
    ['Tirupati (AP)', 'tirupati-ap'],
  ])('%s -> %s', (name, slug) => expect(slugOf(name)).toBe(slug));
});

describe('pointOf', () => {
  it('puts longitude first, as MongoDB wants', () => {
    expect(pointOf('15.8299', '76.3480')).toEqual({
      type: 'Point',
      coordinates: [76.348, 15.8299],
    });
  });
  it.each([
    ['', ''],
    [undefined, undefined],
    ['abc', '76'],
    ['95', '76'],
    ['15', '200'],
  ])('refuses %p, %p', (lat, lng) => expect(pointOf(lat, lng)).toBeUndefined());
});

describe('every demo record becomes a valid document', () => {
  it('cities', () => {
    data.cities.forEach((demo, i) => {
      const document = new City(cityOf(demo, i + 1));
      expect(problems(document)).toBe('');
    });
    const slugs = data.cities.map((demo) => slugOf(demo.name));
    expect(new Set(slugs).size).toBe(slugs.length);
  });

  it('bus types, with the demo keys', () => {
    for (const demo of data.busTypes) {
      const wanted = busTypeOf(demo);
      expect(wanted).toBeDefined();
      expect(problems(new BusType(wanted))).toBe('');
    }
    expect(data.busTypes.map((demo) => busTypeOf(demo)?.key)).toEqual([
      'AC_SLEEPER',
      'NONAC_SLEEPER',
      'AC_SEATER',
      'NONAC_SEATER',
      'VOLVO_AC',
      'SEMI_AC',
    ]);
  });

  it('places, each in a city that exists in the fixture', () => {
    const cityNames = new Set(data.cities.map((city) => city.name));
    for (const demo of data.places) {
      expect(cityNames.has(demo.city)).toBe(true);
      expect(problems(new Location(locationOf(demo, new Types.ObjectId())))).toBe('');
    }
  });

  it('companies: every status is one the real schema knows', () => {
    for (const demo of data.operators) {
      const wanted = operatorOf(demo);
      expect(wanted).toBeDefined();
      expect(problems(new Operator(wanted))).toBe('');
    }
    expect(operatorOf({ id: 'x', name: 'Odd', status: 'WEIRD' })).toBeUndefined();
  });

  it('buses: each belongs to a company and a bus type of the fixture, with a unique registration', () => {
    const operatorIds = new Set(data.operators.map((operator) => operator.id));
    const typeNames = new Set(data.busTypes.map((type) => type.name));
    for (const demo of data.buses) {
      expect(operatorIds.has(demo.operatorId)).toBe(true);
      expect(typeNames.has(demo.type)).toBe(true);
      const wanted = busOf(demo, new Types.ObjectId(), new Types.ObjectId());
      expect(wanted).toBeDefined();
      expect(problems(new Bus(wanted))).toBe('');
    }
    const registrations = data.buses.map((demo) => demo.reg.toUpperCase());
    expect(new Set(registrations).size).toBe(registrations.length);
  });

  it('refuses a bus with a status or registration it cannot use', () => {
    const base = data.buses[0]!;
    expect(
      busOf({ ...base, status: 'WEIRD' }, new Types.ObjectId(), new Types.ObjectId()),
    ).toBeUndefined();
    expect(busOf({ ...base, reg: '' }, new Types.ObjectId(), new Types.ObjectId())).toBeUndefined();
  });
});
