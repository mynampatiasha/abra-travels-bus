// @ts-check
import eslint from '@eslint/js';
import prettierConfig from 'eslint-config-prettier';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist/', 'coverage/', 'node_modules/', 'eslint.config.mjs', 'jest.*.js', 'scripts/'],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  prettierConfig,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    rules: {
      // documentation/project-structure.md §4: no file above ~400 lines
      'max-lines': ['error', { max: 400, skipBlankLines: true, skipComments: true }],
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-console': 'error',
    },
  },
  {
    // Nest modules are decorated empty classes by design
    files: ['**/*.module.ts'],
    rules: { '@typescript-eslint/no-extraneous-class': 'off' },
  },
  {
    // The three-file feature rule (documentation/abra-master-plan.md, Part 3): one backend file and
    // one service file hold a whole feature for one audience, so the ~400-line cap is raised for
    // those files only. Every other file keeps the cap.
    files: [
      '**/*_admin_manage.ts',
      '**/*_admin_manage.service.ts',
      '**/*_client_manage.ts',
      '**/*_client_manage.service.ts',
      '**/*_customer.ts',
      '**/*_customer.service.ts',
      '**/*_driver.ts',
      '**/*_driver.service.ts',
      '**/*_public.ts',
      '**/*_public.service.ts',
      '**/*_chat.ts',
      '**/*_chat.service.ts',
      '**/*_channel.ts',
      '**/*_channel.service.ts',
    ],
    rules: { 'max-lines': ['error', { max: 1200, skipBlankLines: true, skipComments: true }] },
  },
  {
    files: ['**/*.spec.ts', '**/*.e2e-spec.ts'],
    rules: { '@typescript-eslint/unbound-method': 'off' },
  },
);
