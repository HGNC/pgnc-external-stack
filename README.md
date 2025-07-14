# PGNC External Stack

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![Angular](https://img.shields.io/badge/Angular-15+-red.svg)](https://angular.io/)

## Overview

This repository contains the external technology stack for the **PGNC (Plant Gene Nomenclature Committee)** website and database. The PGNC provides standardized gene nomenclature for plant species, serving as a central resource for plant genomics research.

The stack is a containerized microservices architecture that provides a complete web application for plant gene data management, search, and visualization.

## Architecture

The project relies on several microservices/components organized as Docker containers:

### Frontend & API
- **[pgnc-ext-angular](https://github.com/HGNC/pgnc-ext-angular)**: Angular frontend application for the website. See [Angular Documentation](./angular/angular.md) for technical details.
- **[pgnc-api](https://github.com/HGNC/pgnc-api)**: NestJS REST API providing backend services for the website and public API endpoints.

### Search & Indexing
- **[pgnc-solr](https://github.com/HGNC/pgnc-solr)**: Apache Solr search engine for fast gene data retrieval.
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
  - Contains database credentials, API keys, and service configurations

## Quick Start

### Method 1: Manual Setup

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

### Method 2: Automated Setup (macOS/Linux)

```bash
# Clone and setup everything in one command
git clone https://github.com/HGNC/pgnc-external-stack.git
cd pgnc-external-stack
./total-refresh.sh --new --container-tool <docker|podman>
```

### Accessing the Application

- **Website**: <http://localhost:8080>
- **API Documentation**: <http://localhost:3000/api>
- **Solr Admin**: <http://localhost:8983/solr>

## SSL/HTTPS Setup

To enable SSL certificates for production deployment:

```bash
# Build the certbot container
docker compose build certbot

# Generate SSL certificates
docker compose run --rm certbot
```

> **Note**: Ignore transaction-related output messages - these are normal operation logs, not errors.

Example of expected (non-error) output:
```
Hook '--manual-cleanup-hook' for plant.genenames.org ran with error output:
 Transaction started [transaction.yaml].
 Record removal appended to transaction at [transaction.yaml].
 Executed transaction [transaction.yaml] for managed-zone [genenames-org].
```

## Development & Maintenance

### Updating from GitHub

**macOS/Linux (Recommended)**:
```bash
./total-refresh.sh --container-tool <docker|podman>
```

**Windows/Manual**:
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
- [Pylance Configuration](./python/PYLANCE_CONFIG.md)

## Technology Stack

- **Frontend**: Angular 15+, TypeScript, RxJS
- **Backend**: NestJS, Node.js, TypeScript  
- **Database**: PostgreSQL
- **Search**: Apache Solr
- **Containers**: Docker/Podman with Docker Compose
- **Web Server**: Nginx (reverse proxy)
- **SSL**: Let's Encrypt with Certbot
- **Data Processing**: Python 3.8+
- **Testing**: Jest, pytest
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
