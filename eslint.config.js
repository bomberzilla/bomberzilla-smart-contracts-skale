import js from "@eslint/js";
import tseslint from "@typescript-eslint/eslint-plugin";
import tsparser from "@typescript-eslint/parser";

export default [
  js.configs.recommended,
  {
    files: ["**/*.ts", "**/*.js"],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 2020,
        sourceType: "module"
      }
    },
    plugins: {
      "@typescript-eslint": tseslint
    },
    rules: {
      // Disable rules that are problematic with hardhat/viem
      "@typescript-eslint/no-unused-vars": "warn",
      "no-unused-vars": "off",
      // Allow console.log in tests
      "no-console": "off"
    },
    ignores: [
      "node_modules/**",
      "dist/**", 
      "build/**",
      "artifacts/**",
      "cache/**",
      "coverage/**",
      "typechain/**",
      "typechain-types/**"
    ]
  }
];