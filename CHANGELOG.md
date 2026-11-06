# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.1] - 2026-11-06

## [0.8.0] - 2026-11-06

### Changed
- **Nightly runs no longer retry earlier failures automatically** (reverts the 0.7.0 reach-back to the last successful run). Backlog uploads are now a deliberate manual step.
- The report page's "gaps detected" alert now shows the date of the oldest unsubmitted invoice/cashup and a "Review and upload manually" link that opens the report form pre-filled with that range and report type. The existing preview and *Upload to SFTP* button then upload and mark the records as submitted.

### Fixed
- Report form date fields ignored pre-filled dates (from the "Review and upload manually" links and the results-page breadcrumb) and fell back to the default. The template passed `date_format => 'iso'` to `KohaDates`, whose option is `dateformat`, so inputs held system-preference-format dates that Koha's date picker cannot parse.
- Failed runs recorded before 0.7.0 are labelled "Reason not recorded (run predates failure logging)" on upgrade instead of showing a bare "Failed".

## [0.7.0] - 2026-11-05

### Added
- Failed nightly runs now record why: the transport error text (connect, change directory or upload) is stored in a new `message` column on `plugin_oracle_cron_runs` (added by `upgrade`/`install`), shown beside "Failed" on the report page, and written to stderr for cron mail. A missing or unconfigured transport is now logged as a failed run instead of returning silently.
- Configuration changes are now written to Koha's action log (module `ORACLE_PLUGIN`, action `MODIFY`, visible in Tools > Log viewer). Each entry records the user and a JSON diff of old/new values for only the settings that changed; fund and vendor mapping tables are diffed per entry, and the transport name is included for readability. Saves that change nothing are not logged.

### Fixed
- Records from failed nightly runs are now retried: the run window reaches back to the last successful run (at most 30 days) instead of only the previous scheduled day. Submitted records are still excluded, so no duplicates.
- The "gaps detected" counts on the report page were capped at 10 by a row limit; they now show the real number.
- **Transport silently reset on save**: the Transport fieldset is `disabled` in the form when Output is "Local file", and browsers don't submit disabled controls, so saving the page in that mode stored an empty `transport_server` and upload directories (the same happened if no transports existed at the time). Switching back to "Upload" then showed "-- None --". Settings absent from the POST are now left untouched; an explicitly submitted empty value (choosing "-- None --") still clears them.
- Removed the `maximum_version` cap from plugin metadata. Koha's plugins page compares it as a string against the `Version` preference, so any 25.11.x point release (e.g. 25.11.05.x) sorted above `25.11.00.000` and still showed "written for an older version of Koha".

## [0.6.3] - 2026-11-05

### Fixed
- **EDI VAT Correction never ran**: `edi_cron.pl` passes `edifact_messages` ids in the `after_edi_cron` payload (`invoice_ids`), but the hook looked them up as `aqinvoices.invoiceid`. Message ids run ahead of invoice ids, so for recent messages nothing matched and no `[Tax Correction]` adjustment was ever raised. The hook now resolves message ids to invoices via `aqinvoices.message_id` (new `EdiVatCorrector::run_for_message_ids`). Invoices imported before this fix are not corrected retrospectively. New test `t/03-edi-vat-hook.t`; `t/02-edi-vat-corrector.t` gains a case for Askews partial-VAT lines with a bundled zero-rated servicing charge (`MOA+124`/`MOA+125`, `ALC+C`/`MOA+8`).

## [0.6.2] - 2026-11-05

### Added
- **Cashup Tracking**: New database table `plugin_oracle_submitted_cashups` to track successfully processed cashup sessions.
- **Automated Run Tracking**: Plugin now records the timestamp of the `last_cron_run` upon successful completion of all reports.
- **Gap Detection**: The Report tool now identifies and alerts users to unsubmitted invoices or cashup sessions from the last 30 days.
- **Enhanced Submission Manager**: Updated the "Manage Submissions" tool to allow viewing and clearing both submitted invoices and cashup sessions.
- **Smart Cron Processing**: Nightly cron job now automatically excludes previously submitted records for both income and invoices to prevent duplicates.
- New integration test (`t/01-oracle-integration.t`) covering filename generation, plugin metadata, presence of the public/private surface area (install/uninstall/upgrade, manage_submissions, invoice and cashup submission helpers, etc.), config persistence, acquisitions field defaults fall-through, and vendor mapping resolution.
- **EDI VAT Correction**: New `Oracle::EdiVatCorrector`, run via the `after_edi_cron` hook, detects mixed-rate EDI invoice lines that Koha's core ingest overtaxed (it only reads the first `TAX` segment on a `LIN` and ignores the vendor's actual `MOA+124` tax amount) and raises a `Koha::Acquisition::Invoice::Adjustment` for the difference, so both Koha's own invoice total and the Oracle export reflect the vendor's real figures. See Koha core Bug 43510. New test `t/02-edi-vat-corrector.t`.

### Changed

- Adopt the plugin template's CI and release tooling: `npm run release:*` scripts and preflight, `DEVELOPMENT.md`, a `t/00-load.t` smoke test and the GitHub Actions workflow (already current/customised, left as is).
- Remove the legacy zip-based release tooling and committed build artefacts (`Koha/.DS_Store`, `Koha/Plugin/.DS_Store`, `release_kpz.sh`); KPZ files are now built by CI on release tags.

- Relicensed under AGPL-3.0-or-later: added `LICENSE`, SPDX header, and `license`/`license_url` plugin metadata (the licence is also stated in the description, which is what Koha displays).

- Configuration page: split the monolithic "Report Generation Settings" fieldset into "Output & Transport" (with Transport as a nested sub-fieldset) and a separate "Run days" fieldset; render Run days checkboxes horizontally; add a hint explaining Local file vs Upload modes
- Configuration page: add an explicit "-- None --" option to the Transport server select so an unconfigured state is no longer misrepresented by the first listed transport appearing selected by default
- Configuration page: disable the Transport sub-fieldset when Output is set to "Local file", with an info banner clarifying that Transport settings are unused in that mode

### Fixed

- Configuration page: rename the Output select's id from `output` to `report_output` to avoid a CSS clash with an upstream Koha rule on `#output`
- Replace stray `plugins_rbkc_oracle` body id copy-paste leftovers in the configure, report-step1 and report-step2 templates with the correct `plugins_wscc_oracle` id
- Metadata `maximum_version` was still capped at `25.05.00.000`, triggering an "outdated plugin" warning on the plugins page now WSCC is on 25.11.o5th; raised to `25.11.00.000`

[Unreleased]: https://github.com/openfifth/koha-plugin-wscc-oracle/compare/v0.8.1...HEAD
[0.8.1]: https://github.com/openfifth/koha-plugin-wscc-oracle/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/openfifth/koha-plugin-wscc-oracle/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/openfifth/koha-plugin-wscc-oracle/compare/v0.6.3...v0.7.0
[0.6.3]: https://github.com/openfifth/koha-plugin-wscc-oracle/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/openfifth/koha-plugin-wscc-oracle/compare/v0.6.1...v0.6.2