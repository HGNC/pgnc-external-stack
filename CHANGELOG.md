# Changelog

All notable documentation changes for this repository.

## 2025-09-12

- Docs: Consolidated SSL renewal documentation and testing updates.
  - Folded content from `RENEWAL_IMPLEMENTATION_SUMMARY.md` into this changelog; `SSL_RENEWAL_SETUP.md` remains the canonical how-to.
  - Folded content from `TEST_SUITE_UPDATES.md` into this changelog.
  - Removed redundant `README_UPDATES.md` reference from README and added a Documentation Index.

### SSL Certificate Auto-Renewal (Summary)

- Added `--renew-certs` option to `total-refresh.sh` and `renew_certificates()` function.
- Introduced standalone `cert-renewal.sh` for cron-friendly renewals with logging and validations.
- Updated `SSL_RENEWAL_SETUP.md` with complete setup, troubleshooting, and monitoring guidance.
- Recommended cron: `30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh docker >> /var/log/pgnc-cert-renewal.log 2>&1`.

### Test Suite Updates (Highlights)

- `test_total-refresh.sh`: Added tests for `--renew-certs`, conflict detection with `--new`/`--clean-volumes`, nginx reload, and error handling. 52 tests, all passing.
- `test_cert-renewal.sh`: New suite covering docker/podman support, logging, errors, and prerequisites.
- Improvements: Enhanced assertions, isolated mock environments, clearer help text examples.

## 2025-09-11

- Docs: Standardized Apache Solr references to 9.9.0 across Markdown files.
- Docs: Updated cache guidance to CaffeineCache (Solr 9.x) and clarified Java 11+ requirement.
- Docs: Removed outdated Lucene 8.x references; use match version aligned with Solr 9.x.
- Docs: Fixed fenced code blocks to include language hints where missing.
- Verification: Searched non-markdown configs (`docker-compose.yml`, Dockerfiles, scripts, env samples) for `Solr 8`/`solr:8`/`Lucene 8`; none found, no config changes required.
