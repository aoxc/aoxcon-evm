const prettierPlugin = require('eslint-plugin-prettier');

module.exports = [
  { ignores: ['node_modules/**'] },
  {
    files: ['src/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'commonjs',
      globals: {
        process: 'readonly',
        module: 'readonly',
        require: 'readonly',
        __dirname: 'readonly',
        console: 'readonly',
      },
    },
    plugins: { prettier: prettierPlugin },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off',
      indent: ['error', 2],
      'linebreak-style': ['error', 'unix'],
      quotes: ['error', 'single'],
      semi: ['error', 'always'],
      'prettier/prettier': 'error',
    },
  },
];
