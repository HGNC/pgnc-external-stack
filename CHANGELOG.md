# Changelog

All notable documentation changes for this repository.

## 2025-09-11

- Docs: Standardized Apache Solr references to 9.9.0 across Markdown files.
- Docs: Updated cache guidance to CaffeineCache (Solr 9.x) and clarified Java 11+ requirement.
- Docs: Removed outdated Lucene 8.x references; use match version aligned with Solr 9.x.
- Docs: Fixed fenced code blocks to include language hints where missing.
- Verification: Searched non-markdown configs (`docker-compose.yml`, Dockerfiles, scripts, env samples) for `Solr 8`/`solr:8`/`Lucene 8`; none found, no config changes required.
