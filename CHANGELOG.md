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

### Changed

- Configuration page: split the monolithic "Report Generation Settings" fieldset into "Output & Transport" (with Transport as a nested sub-fieldset) and a separate "Run days" fieldset; render Run days checkboxes horizontally; add a hint explaining Local file vs Upload modes
- Configuration page: add an explicit "-- None --" option to the Transport server select so an unconfigured state is no longer misrepresented by the first listed transport appearing selected by default
- Configuration page: disable the Transport sub-fieldset when Output is set to "Local file", with an info banner clarifying that Transport settings are unused in that mode

### Fixed

- Configuration page: rename the Output select's id from `output` to `report_output` to avoid a CSS clash with an upstream Koha rule on `#output`
