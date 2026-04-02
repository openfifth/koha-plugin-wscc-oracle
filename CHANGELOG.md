# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Cashup Tracking**: New database table `plugin_oracle_submitted_cashups` to track successfully processed cashup sessions.
- **Automated Run Tracking**: Plugin now records the timestamp of the `last_cron_run` upon successful completion of all reports.
- **Gap Detection**: The Report tool now identifies and alerts users to unsubmitted invoices or cashup sessions from the last 30 days.
- **Enhanced Submission Manager**: Updated the "Manage Submissions" tool to allow viewing and clearing both submitted invoices and cashup sessions.
- **Smart Cron Processing**: Nightly cron job now automatically excludes previously submitted records for both income and invoices to prevent duplicates.
