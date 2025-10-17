# PGNC External Stack

PGNC External Stack packages the Plant Gene Nomenclature Committee web application, public API, search infrastructure, and supporting ETL tooling into a reproducible Docker Compose deployment. The repository includes the Compose definition, Docker wrapper images that embed seed data, and helper scripts needed to run the stack locally or in small-team environments.

---

## Contents

| Service | Image | Role |
| ------- | ----- | ---- |
| `angular` | `ghcr.io/hgnc/pgnc-angular:latest` | Angular UI; runtime credentials injected from environment variables. |
| `api` | `ghcr.io/hgnc/pgnc-api:latest` | NestJS backend for UI and public clients. |
| `pgncdb` | built locally as `pgnc-postgres-local` | PostgreSQL 17 seeded from `db-data/docker-entrypoint-initdb.d/`. |
| `solr` | built locally as `pgnc-solr-local` | Apache Solr 9 core seeded from `solr/cores/data/`. |
| `python` | built locally as `pgnc-python-local` | ETL scripts that populate PostgreSQL and prepare Solr exports. |
| `solr-client` | `ghcr.io/hgnc/pgnc-solr-client:latest` | Authenticated gateway between the UI and Solr. |
| `nginx` | `ghcr.io/hgnc/pgnc-nginx:latest` | Edge proxy for HTTP/HTTPS entry points. |
|| `certbot` | `ghcr.io/hgnc/pgnc-certbot:latest` | Let's Encrypt DNS-01 renewals via Google Cloud DNS. |

Named volumes persist runtime state: `pgnc-data` (PostgreSQL), `solr-data` (Solr cores), `python-input`/`python-output` (ETL workspace), and `certbot-etc` (ACME configuration and certificates).

---

## Prerequisites

- Docker 24+ with the Compose plugin (`docker compose`)
- Git
- Bash-compatible shell with `curl` and `wget`
- (TLS only) Google Cloud service account key with DNS management permissions

---

## Configure Environment Variables

`sample.env` is a template. **Populate it with real credentials and rename it to `.env` before starting the stack.** Compose only reads `.env`; leaving the template untouched will cause services to fail.

```bash
cp sample.env .env
```

Edit `.env` and replace every placeholder (database credentials, Solr admin account, API user/password, JWT secrets, mail settings, host ports, etc.).

### SSL/HTTPS Certificate Configuration

The PGNC External Stack supports automatic SSL certificate provisioning and renewal using Let's Encrypt with Google Cloud DNS integration.

**Quick Setup Summary:**
1. Create a Google Cloud service account with DNS Admin permissions
2. Configure SSL environment variables in `.env`
3. Build the Certbot container and request initial certificates
4. Set up automated renewal with cron

**📋 For complete step-by-step SSL setup instructions, see [`SSL_SETUP.md`](SSL_SETUP.md)**

The SSL setup document includes:
- Detailed Google Cloud service account creation
- Complete environment variable configuration
- Certificate request examples (single domain, multiple domains, wildcards)
- Automated renewal setup with cron
- Comprehensive troubleshooting guide

`.env` is ignored by Git—do not commit real secrets.

---

## Build Local Wrapper Images

Three services build locally from Dockerfiles. Rebuild them after cloning or whenever their source directories change.

```bash
docker compose build python pgncdb solr
```

- `docker/python.Dockerfile` copies the ETL scripts and seed SQL into the Python image.
- `docker/postgres.Dockerfile` copies the SQL migrations/dumps into `/docker-entrypoint-initdb.d/` so PostgreSQL self-seeds.
- `docker/solr.Dockerfile` copies the Solr core and adjusts ownership for first-run seeding.

---

## Start the Stack

```bash
docker compose up -d
```

- Published images (Angular, API, Solr client, Nginx, Certbot) are pulled automatically.
- Health checks ensure Solr and PostgreSQL are ready before dependent services start.
- The Python container runs to completion, seeding the database and generating Solr exports into the `python-output` volume.

Stop everything with `docker compose down`. Add `--volumes` **only** when you intentionally want to discard persisted data and certificates.

---

## Key Endpoints (defaults)

| Endpoint | Description | Notes |
| -------- | ----------- | ----- |
| `http://localhost:${LOCALHOST_ANGULAR_PORT}` (default `4000`) | Angular UI | Credentials auto-filled using `API_USER` / `API_PASSWORD` from `.env`. |
| `http://localhost:${LOCALHOST_API_PORT}` (default `3001`) | API | Authenticates with the same API credentials. |
| `http://localhost:${LOCALHOST_SOLR_PORT}/solr` (default `8983`) | Solr admin | Basic auth via `SOLR_ADMIN_USER` / `SOLR_ADMIN_PASSWORD`. |
| `http://localhost:${LOCALHOST_SOLR_CLIENT_PORT}` (default `3000`) | Solr client gateway | Proxies UI search traffic. |
| `http://localhost:${LOCALHOST_NGINX_PORT}` / `https://localhost:${LOCALHOST_NGINX_SSL_PORT}` | Nginx edge proxy | Serves Angular/API and, once Certbot has run, HTTPS. |

All host ports are configurable through `LOCALHOST_*` variables in `.env`.

---

## Routine Operations

- **Regenerate data**
  ```bash
  docker compose run --rm python
  ```
  Re-runs the ETL scripts, repopulating PostgreSQL and rebuilding Solr exports.

- **Inspect logs**
  ```bash
  docker compose logs -f <service>
  ```

- **Check status**
  ```bash
  docker compose ps
  ```

- **Renew SSL certificates**
  ```bash
  # Standard renewal (automatically detects docker/podman and restarts nginx)
  ./cert-renewal.sh
  
  # Test renewal without making changes
  ./cert-renewal.sh --dry-run
  
  # Force specific container tool
  ./cert-renewal.sh --container-tool podman
  
  # Renew without restarting nginx
  ./cert-renewal.sh --no-restart
  ```
  
  **Certificate Management Commands:**
  ```bash
  # Request new certificates (first-time setup)
  docker compose --profile ssl run --rm certbot
  
  # Check certificate status
  docker compose --profile ssl run --rm certbot certificates
  
  # Force renewal (even if not due)
  docker compose --profile ssl run --rm certbot renew --force-renewal
  
  # Test configuration without actual renewal
  docker compose --profile ssl run --rm certbot renew --dry-run
  ```
  
  **Automated Renewal with Cron:**
  ```bash
  # Add to crontab for twice-daily renewal checks
  30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh >> /var/log/pgnc-cert-renewal.log 2>&1
  ```
  
  Refer to `SSL_SETUP.md` for complete SSL setup instructions, advanced configuration, and troubleshooting.

---

## Testing & Linting

| Area | Command | Notes |
| ---- | ------- | ----- |
| Shell scripts | `npm run test:shell` | Runs the tests in `tests/`. |
| Docs | `npm run lint:docs` | Markdown formatting and link checks. |
| Python ETL | `cd python && pytest` | Requires a local Python environment. |
| Angular (optional) | `cd angular && npm test` | Run if you have the Angular source checked out. |
| API (optional) | `cd api && npm test` | Run if you have the API source checked out. |

---

## Troubleshooting

| Symptom | Suggested Checks |
| ------- | ----------------- |
| Service stuck in `starting` | Inspect logs; verify `.env` values and confirm the Python ETL job completed. |
| API login returns `400`/`401` | Ensure `API_USER` / `API_PASSWORD` match the seeded credentials. |
| Solr health check fails | Double-check admin credentials; if needed, remove `solr-data` volume and restart. |
| **SSL Certificate Issues** | **Troubleshooting Steps** |
| Certificate request fails | Verify `GCP_PROJECT`, `GCP_DNS_ZONE`, and DNS permissions; check `docker compose --profile ssl run --rm certbot --dry-run`. |
| DNS challenge failures | Confirm service account has DNS Admin role; increase `GCP_DNS_PROPAGATION_WAIT` if needed. |
| Authentication errors | Verify `GCP_KEY_FILE` path exists and contains valid service account JSON; check `GOOGLE_APPLICATION_CREDENTIALS` mount. |
| Renewal script failures | Run `./cert-renewal.sh --dry-run` first; check Docker/Podman is running; verify compose file syntax. |
| Nginx not restarting | Ensure nginx service is running; check `docker compose ps nginx`; verify SSL profile configuration. |
| Port binding failures | Adjust `LOCALHOST_*` variables or free the conflicting host port. |

To reset a stateful service completely, stop the stack and remove the relevant volume. Example:

```bash
docker compose down
docker volume rm pgnc-external-stack_pgnc-data
docker compose up -d
```

---

## Repository Layout

```
db-data/                     # SQL executed during PostgreSQL image build
solr/                        # Solr core configuration copied into the Solr image
docker/                      # Dockerfiles for python, postgres, solr wrappers
python/                      # ETL scripts baked into the python image (bin/, data-load/, data-update/)
sample.env                   # Environment template (copy -> .env)
docker-compose.yml           # Service definitions, networks, volumes
cert-renewal.sh              # Helper script for certbot container
SSL_SETUP.md                 # Complete SSL certificate setup and renewal guide
LICENSE                      # AGPL-3.0 license text
```

---

## Contributing

1. Fork the repository and create a feature branch (`git checkout -b feature/my-change`).
2. Make your updates and add/adjust tests as needed.
3. Run the relevant test suites or rebuild affected images.
4. Open a pull request describing the change and validation steps.

Please do not commit real credentials. Keep secrets exclusively in your local `.env`.

---

## License

PGNC External Stack is distributed under the GNU Affero General Public License v3.0. See `LICENSE` for the full text.
