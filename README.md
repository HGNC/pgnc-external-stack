# PGNC External Stack

## Overview

This repository contains the external technology stack for the PGNC website and database.

The project relies on several submodules/projects. These are:

- [pgnc-ext-angular](https://github.com/HGNC/pgnc-ext-angular): The main frontend code for the website.
- [pgnc-api](https://github.com/HGNC/pgnc-api): REST API for the site and soon for the public.
- [pgnc-solr](https://github.com/HGNC/pgnc-solr): The Apache Solr search engine for the site.
- [pgnc-ext-solr-data](https://github.com/HGNC/pgnc-ext-solr-data): Persistent volume for the Solr search.
- [pgnc-solr-client](https://github.com/HGNC/pgnc-solr-client): A thin server side client to allow the website to interact with the search server without exposing it to the outside world.
- [pgnc_solr_load](https://github.com/HGNC/pgnc_solr_load): Runs only on startup. Connects to the DB and Solr and fills Solr with indexed data from the DB.
- [pgnc_db_schema](https://github.com/HGNC/pgnc_db_schema): Persistent volume for the DB. Also contains the gzipped data that is loaded during startup.
- [pgnc-ext-nginx](https://github.com/HGNC/pgnc-ext-nginx): Reverse proxy and load balancer for the external-facing components of the PGNC stack.
- [pgnc-certbot](https://github.com/HGNC/pgnc-certbot): Handles SSL certificate creation and renewal using Let's Encrypt.

## Requirements

- Docker or Podman or OrbStack: To build and run the container.
- `gcp-key.json`: You need a JSON key file of a Google Cloud Platform service account which has access to the Cloud DNS. This is used for the certbot container and needs to be placed in the certbot root directory.
- `.env`: A file containing all the environment variables needed for the all the containers. This file must be placed in the root of the pgnc-external-stack. To create your own, make edits to the sample.env file and then rename it to .env.

## Installation

```bash
# Clone the repository
git clone --recursive https://github.com/HGNC/pgnc-external-stack.git;
# Enter the project directory
cd pgnc-external-stack;
# Copy sample.env to .env and change the values for your instances
cp sample.env .env
# Run using docker compose
docker compose up -d
# Or use podman compose
podman compose up -d
```

Or use the shell script provided if using a mac or linux machine

```bash
git clone https://github.com/HGNC/pgnc-external-stack.git;
cd pgnc-external-stack;
./total-refresh.sh --new --container-tool <podman | docker>
```

The site should be available at <http://localhost:8080>

## Set up for SSL (i.e HTTPS)

Do the above first and then run the following commands:

```BASH
docker compose build certbot;
docker compose run --rm certbot;
```

Please ignore any errors that look like the one below as they are not errors:

```TEXT
Hook '--manual-cleanup-hook' for plant.genenames.org ran with error output:
 Transaction started [transaction.yaml].
 Record removal appended to transaction at [transaction.yaml].
 Executed transaction [transaction.yaml] for managed-zone [genenames-org].
 Created [https://dns.googleapis.com/dns/v1/projects/.......
```

## Refreshing the code from the github repo

Use the **total-refresh.sh** shell script if you are running on a mac or linux.

```bash
./total-refresh.sh --container-tool <podman | docker>
```

On windows you need to do the following:

```bash
docker compose down
docker image prune --all --force
docker volume prune --force
docker network prune --force
git pull --recurse-submodules
docker compose up -d
```

## Testing

There are no tests currently, however, if tests were to be created in future, use Jest rather than Karma
as karma is no longer supported and Jest will replace karma in the near future within Angular.

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the GNU AFFERO GENERAL PUBLIC LICENSE v3.0 - see the [LICENSE](LICENSE) file for details.
