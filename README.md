# Koha Oracle Finance Integration Plugin (WSCC)

A Koha plugin to manage finance integration with Oracle for West Sussex County Council (WSCC).

This plugin manages the generation and automated delivery of financial reports for acquisitions (invoices) and income (cashups).

## Features

- **Automated Nightly Processing**: Delivers daily reports via SFTP.
- **Acquisitions Invoices**: Formats and tracks submitted invoices.
- **Income (Cashups)**: Aggregates cashup sessions with per-line VAT calculation.
- **Gap Detection**: Automatically alerts users to unsubmitted records from the last 30 days.
- **Submission Tracking**: Tracks successfully processed records to prevent duplicates.
- **Management Tool**: "Manage Submissions" tool allows viewing and allowing resubmission of records.

## Usage

1. **Configuration**: Set up SFTP transport and report schedules in the plugin settings.
2. **Automated Run**: The `cronjob_nightly` method should be scheduled to run daily via Koha's cron system.
3. **Manual Reports**: Use the "Run Report" tool in the plugin menu to generate manual reports or catch up on missing gaps.
4. **Resubmission**: If a record needs to be re-sent, use the "Manage Submissions" tool to clear its submission status.
