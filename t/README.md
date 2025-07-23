# Testing Framework

This directory contains tests for the SAP finance integration plugin.

## Running Tests

To run the tests, use the standard Perl test harness:

```bash
prove t/
```

## Test Structure

- `00-load.t` - Basic module loading test
- Additional test files can be added following the pattern `##-description.t`

## Test Environment

Tests should be run in a Koha development environment with the plugin system enabled.

## Adding Tests

When adding new functionality to the plugin, please add corresponding tests:

1. Create a new test file in this directory
2. Use descriptive filenames (e.g., `10-report-generation.t`)
3. Follow standard Perl testing practices
4. Test both success and error conditions