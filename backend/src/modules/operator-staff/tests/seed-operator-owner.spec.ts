import { validateLocalTestEnvironment } from '../../../seed-operator-owner';

describe('validateLocalTestEnvironment', () => {
  it('accepts localhost with a _test database', () => {
    const res = validateLocalTestEnvironment('mongodb://localhost:27017/abra_staff_test?directConnection=true');
    expect(res.isLocal).toBe(true);
    expect(res.isTestDb).toBe(true);
    expect(res.dbName).toBe('abra_staff_test');
  });

  it('accepts 127.0.0.1 with a _test database', () => {
    const res = validateLocalTestEnvironment('mongodb://127.0.0.1:27017/abra_travels_test');
    expect(res.isLocal).toBe(true);
    expect(res.isTestDb).toBe(true);
    expect(res.dbName).toBe('abra_travels_test');
  });

  it('rejects remote hosts even if database is _test', () => {
    const res = validateLocalTestEnvironment('mongodb+srv://user:pass@cluster0.mongodb.net/abra_staff_test');
    expect(res.isLocal).toBe(false);
    expect(res.isTestDb).toBe(true);
  });

  it('rejects non-_test database even on localhost', () => {
    const res = validateLocalTestEnvironment('mongodb://localhost:27017/abra_production');
    expect(res.isLocal).toBe(true);
    expect(res.isTestDb).toBe(false);
  });
});
