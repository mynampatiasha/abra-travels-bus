import { type AppEnvironment } from './environment.schema';

/**
 * Typed, validated configuration. Inject this instead of reading `process.env`.
 * Never log the whole configuration — it contains secrets.
 */
export class AppConfigService {
  constructor(private readonly values: AppEnvironment) {}

  get<Key extends keyof AppEnvironment>(key: Key): AppEnvironment[Key] {
    return this.values[key];
  }

  get isProduction(): boolean {
    return this.values.NODE_ENV === 'production';
  }

  /** Swagger UI: on by default outside production, rejected by validation in production. */
  get apiDocsEnabled(): boolean {
    return this.values.API_DOCS_ENABLED ?? !this.isProduction;
  }
}
