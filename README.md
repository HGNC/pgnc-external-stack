# PGNC External Stack

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/python-3.13+-blue.svg)](https://www.python.org/downloads/)
[![Angular](https://img.shields.io/badge/Angular-19.1+-red.svg)](https://angular.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17.0-blue.svg)](https://www.postgresql.org/)
[![Apache Solr](https://img.shields.io/badge/Apache%20Solr-8.x-orange.svg)](https://solr.apache.org/)
[![NestJS](https://img.shields.io/badge/NestJS-10.x-red.svg)](https://nestjs.com/)

## Overview

This repository contains the external technology stack for the **PGNC (Plant Gene Nomenclature Committee)** website and database. The PGNC provides standardized gene nomenclature for plant species, serving as a central resource for plant genomics research.

The stack is a containerized microservices architecture that provides a complete web application for plant gene data management, search, and visualization.

## Architecture

The project relies on several microservices/components organized as Docker containers:

### Frontend & API

- **[pgnc-ext-angular](https://github.com/HGNC/pgnc-ext-angular)**: Angular frontend application for the website. See [Angular Documentation](./angular/angular.md) for technical details.
- **[pgnc-api](https://github.com/HGNC/pgnc-api)**: NestJS REST API providing backend services for the website and public API endpoints.

### Search & Indexing

- **[pgnc-solr](https://github.com/HGNC/pgnc-solr)**: Apache Solr search engine for fast gene data retrieval with BasicAuth security enabled.
- **[pgnc-solr-client](https://github.com/HGNC/pgnc-solr-client)**: Server-side client that provides a secure interface between the frontend and Solr.
- **[pgnc_solr_load](https://github.com/HGNC/pgnc_solr_load)**: Initial data loading service that populates Solr with indexed gene data from the database.
- **python/**: Python utilities for data processing and Solr index management, including:
  - Data loading and updating scripts
  - Gene model definitions
  - Comprehensive test suites

### Data & Infrastructure  

- **[pgnc_db_schema](https://github.com/HGNC/pgnc_db_schema)**: PostgreSQL database schema and initial data (gzipped).
- **[pgnc-ext-solr-data](https://github.com/HGNC/pgnc-ext-solr-data)**: Persistent volume for Solr search indices.
- **[pgnc-ext-nginx](https://github.com/HGNC/pgnc-ext-nginx)**: Reverse proxy and load balancer for external-facing components.
- **[pgnc-certbot](https://github.com/HGNC/pgnc-certbot)**: SSL certificate management using Let's Encrypt.

## Prerequisites

- **Container Runtime**: Docker, Podman, or OrbStack for building and running containers
- **Git**: For cloning the repository and submodules
- **Google Cloud Platform Access** (for SSL):
  - `gcp-key.json`: Service account key file with Cloud DNS access
  - Place in the `certbot/` directory for SSL certificate management
- **Environment Configuration**:
  - `.env` file: Copy `sample.env` to `.env` and configure for your environment
  - Contains database credentials, API keys, Solr authentication credentials, and service configurations

## Quick Start

### Method 1: Automated Setup (Recommended)

The `total-refresh.sh` script provides automated environment setup and management for the PGNC stack. This is the recommended approach for both new installations and regular maintenance.

#### New Environment Setup

```bash
# Clone the repository
git clone --recursive https://github.com/HGNC/pgnc-external-stack.git
cd pgnc-external-stack

# Configure environment variables
cp sample.env .env
# Edit .env with your specific configuration
# You could also cp a .env into the root of the project

# If using SSL add your gcp-key.json to certbot
cp ../gcp-key.json certbot/gcp-key.json

# Set up new environment with Docker
./total-refresh.sh --new --container-tool docker

# Or with Podman
./total-refresh.sh --new --container-tool podman

# Using SSL then run the above with --ssl
./total-refresh.sh --new --container-tool docker --ssl
```

#### Environment Refresh/Update

```bash
# Refresh existing environment (pulls latest code and rebuilds)
./total-refresh.sh --container-tool docker

# Refresh with SSL certificate generation
./total-refresh.sh --container-tool docker --ssl

# Certificate renewal only (maintenance mode)
./total-refresh.sh --container-tool docker --renew-certs

# Clean refresh (removes all volumes - destroys data!)
./total-refresh.sh --container-tool docker --clean-volumes
```

#### Script Features

- **Automated Dependency Checking**: Validates Docker/Podman, Git, and jq installation
- **Environment Validation**: Checks `.env` file configuration and required variables
- **Submodule Management**: Handles Git submodule initialization and updates with fallback strategies
- **Service Orchestration**: Manages proper startup sequence and health monitoring
- **SSL Support**: Optional Let's Encrypt certificate generation with Certbot
- **Resource Cleanup**: Intelligent cleanup of unused containers, images, and optionally volumes
- **Health Monitoring**: Waits for all services to reach healthy state (up to 10 minutes)
- **Status Reporting**: Displays service status and access URLs upon completion

#### Script Options

| Option | Description |
|--------|-------------|
| `--new` | Set up a new environment from scratch |
| `--container-tool TOOL` | Container tool to use (`docker` or `podman`) **[Required]** |
| `--ssl` | Enable SSL certificate generation with Certbot |
| `--renew-certs` | Renew SSL certificates only (no full refresh) |
| `--clean-volumes` | Remove all volumes during cleanup ⚠️ **Destroys all data** |
| `--verbose` | Enable verbose output for debugging |
| `--help` | Show detailed help information |

#### Prerequisites for Script

- **Container Runtime**: Docker or Podman with Compose plugin
- **Git**: For repository and submodule management
- **jq**: For JSON parsing of container status

  ```bash
  # macOS
  brew install jq
  
  # Ubuntu/Debian
  sudo apt-get install jq

  
  # CentOS/RHEL
  sudo yum install jq
  ```

- **Environment File**: Valid `.env` file (copy from `sample.env`)
- **SSL (Optional)**: Google Cloud credentials in `certbot/gcp-key.json`

### Method 2: Manual Setup

For users who prefer manual control or are on Windows:

```bash
# Clone the repository with all submodules
git clone --recursive https://github.com/HGNC/pgnc-external-stack.git

# Enter the project directory
cd pgnc-external-stack

# Configure environment variables
cp sample.env .env
# Edit .env with your specific configuration

# Start all services
docker compose up -d

# Or using Podman
podman compose up -d
```

### Accessing the Application

- **Website**: <http://localhost:8080>
- **API Documentation**: <http://localhost:3000/api>
- **Solr Admin**: <http://localhost:8983/solr> (Apache Solr 8.x)

## SSL/HTTPS Setup

To enable SSL certificates for production deployment:

```bash
# Build the certbot container
docker compose build certbot

# Generate SSL certificates
docker compose run --rm certbot
```

### SSL Certificate Auto-Renewal

Let's Encrypt certificates expire every 90 days. The PGNC stack includes automated renewal functionality to prevent service interruption:

```bash
# Manual certificate renewal
./total-refresh.sh --container-tool docker --renew-certs


# Or use the dedicated renewal script
./cert-renewal.sh docker
```

**For automated renewal with cron**:

```bash
# Edit crontab to run twice daily
crontab -e


# Add this line (adjust path to your project directory):
30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh docker >> /var/log/pgnc-cert-renewal.log 2>&1
```

For detailed setup instructions, see:

- 📋 **[SSL Renewal Setup Guide](./SSL_RENEWAL_SETUP.md)** - Complete configuration instructions
- 📊 **[Renewal Implementation Summary](./RENEWAL_IMPLEMENTATION_SUMMARY.md)** - Technical implementation details

> **Note**: Ignore transaction-related output messages - these are normal operation logs, not errors.

Example of expected (non-error) output:

```
Hook '--manual-cleanup-hook' for plant.genenames.org ran with error output:
 Transaction started [transaction.yaml].
 Record removal appended to transaction at [transaction.yaml].
 Executed transaction [transaction.yaml] for managed-zone [genenames-org].
```

## Development & Maintenance

### Using the total-refresh.sh Script (Recommended)

The automated script handles most maintenance tasks:

```bash
# Standard refresh (updates code, rebuilds containers)
./total-refresh.sh --container-tool docker

# Refresh with SSL certificate renewal
./total-refresh.sh --container-tool docker --ssl

# Certificate renewal only (for cron jobs)
./total-refresh.sh --container-tool docker --renew-certs

# Deep clean refresh (removes all data volumes)
./total-refresh.sh --container-tool docker --clean-volumes


# Verbose output for troubleshooting
./total-refresh.sh --container-tool docker --verbose
```

#### What the Script Does

**For New Environments (`--new` flag)**:

1. Validates system prerequisites (Docker/Podman, Git, jq)

2. Checks environment configuration (`.env` file)
3. Initializes Git submodules from scratch
4. Builds all container images with fresh cache
5. Starts services in proper dependency order
6. Monitors service health until all are ready
7. Optionally generates SSL certificates
8. Displays status and access URLs

**For Environment Refresh (default)**:

1. Stops all running services gracefully
2. Cleans up unused containers, images, and networks

3. Optionally removes data volumes (with `--clean-volumes`)
4. Updates Git submodules with fallback strategies
5. Rebuilds all container images
6. Restarts services with health monitoring
7. Optionally renews SSL certificates
8. Reports final status

#### Service Health Monitoring

The script monitors different service types appropriately:

- **Long-running services** (database, API, frontend, Solr): Must reach "healthy" status
- **Task services** (Python data loader): Must exit with code 0
- **Nginx**: Health depends on SSL configuration

Timeout: 10 minutes with progress updates every 30 seconds.

#### Troubleshooting with the Script

```bash
# Check what the script requires
./total-refresh.sh --help

# Run with verbose output
./total-refresh.sh --container-tool docker --verbose

# If services fail to start, check logs

docker compose logs -f

# For submodule issues, the script provides manual commands
git submodule status

git submodule deinit --all -f
git submodule update --init --recursive
```

#### Script Error Handling

The script uses `set -euo pipefail` for strict error handling:

- **Exit Code 0**: Successful completion
- **Exit Code 1**: Error occurred (invalid arguments, missing dependencies, setup failure)

Common error scenarios and solutions:

- **Missing container tool**: Install Docker or Podman with Compose plugin
- **Missing jq**: Install jq for JSON parsing (`brew install jq` on macOS)

- **Invalid .env**: Copy `sample.env` to `.env` and configure all required variables
- **Submodule failures**: Script provides fallback strategies and manual recovery commands
- **Service health timeouts**: Check container logs for specific service errors

The script provides colored output:

- 🔵 **Blue [INFO]**: General information
- 🟢 **Green [SUCCESS]**: Successful operations
- 🟡 **Yellow [WARNING]**: Non-critical issues
- 🔴 **Red [ERROR]**: Critical failures

### Manual Maintenance (Alternative)

For users who prefer manual control:

```bash
# Stop all services
docker compose down

# Clean up resources
docker image prune --all --force
docker volume prune --force  
docker network prune --force

# Update code
git pull --recurse-submodules

# Restart services
docker compose up -d
```

### Working with Python Components

The `python/` directory contains data processing utilities:

```bash
# Install Python dependencies
cd python
pip install -r requirements.txt

# Run data loading scripts
python bin/data-load/main.py


# Run data update scripts  
python bin/data-update/main.py

# Run tests
pytest tests/

```

See [python/README.md](./python/README.md) for detailed Python component documentation.

## Testing

The project includes comprehensive test suites:

### Python Tests

- **Location**: `python/tests/`
- **Framework**: pytest with comprehensive coverage
- **Coverage**: Gene models, data processing, API integrations
- **Run**: `cd python && pytest tests/ -v`

### Frontend Tests  

- **Framework**: Jest (replaces deprecated Karma)
- **Location**: `angular/src/`
- **Run**: `cd angular && npm test`

### API Tests

- **Framework**: Jest with NestJS testing utilities
- **Location**: `api/src/`
- **Run**: `cd api && npm test`

For detailed testing information, see [python/TESTING_SUMMARY.md](./python/TESTING_SUMMARY.md).

## Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`

3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Test** your changes thoroughly
5. **Push** to your branch: `git push origin feature/amazing-feature`
6. **Submit** a Pull Request

### Development Guidelines

- Follow existing code style and conventions
- Include tests for new functionality
- Update documentation as needed
- Ensure all tests pass before submitting PR

## Troubleshooting

### Common Issues

**Port Conflicts**: If you see port binding errors, check that ports 8080, 3000, 8983, 5432 are available.

**Docker Issues**: Try cleaning up Docker resources:

```bash
docker system prune -a
docker volume prune
```

**Database Connection**: Verify your `.env` file has correct database credentials.

**SSL Certificate Issues**: Ensure your GCP service account has proper DNS permissions.

## Documentation

- [Python Components](./python/README.md)
- [Angular Frontend](./angular/angular.md)  
- [Testing Guide](./python/TESTING_SUMMARY.md)
- [Test Suite Updates](./TEST_SUITE_UPDATES.md)
- [Pylance Configuration](./python/PYLANCE_CONFIG.md)
- [SSL Certificate Renewal Setup](./SSL_RENEWAL_SETUP.md)
- [SSL Renewal Implementation Summary](./RENEWAL_IMPLEMENTATION_SUMMARY.md)

## Technology Stack

- **Frontend**: Angular 19.1+, TypeScript, RxJS
- **Backend**: NestJS 10.x, Node.js, TypeScript  
- **Database**: PostgreSQL 17.0
- **Search**: Apache Solr 8.x (Lucene 8.5.2)
- **Containers**: Docker/Podman with Docker Compose
- **Web Server**: Nginx (reverse proxy)
- **SSL**: Let's Encrypt with Certbot
- **Data Processing**: Python 3.13+
- **Testing**: Jest, pytest 8.4+
- **Cloud**: Google Cloud Platform (DNS management)

## License

This project is licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0).

- **Commercial Use**: Permitted with source disclosure
- **Distribution**: Must include license and copyright notice  
- **Patent Use**: Expressly granted
- **Private Use**: Permitted
- **Network Use**: Must provide source code

See the [LICENSE](LICENSE) file for the complete terms.

---

**Plant Gene Nomenclature Committee (PGNC)**  
*Standardizing plant gene nomenclature for the global research community*
