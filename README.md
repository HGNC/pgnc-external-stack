# PGNC External Stack

## Overview

This repository contains the external technology stack for the PGNC website and database.

The project relies on several submodules/projects. These are:

- [pgnc-ext-angular](https://github.com/HGNC/pgnc-ext-angular): The main frontend code for the website.
- [pgnc-api](https://github.com/HGNC/pgnc-api): REST API for the site and soon for the public.
- [pgnc-solr](https://github.com/HGNC/pgnc-solr): The Apache Solr search engine for the site.
- [pgnc-ext-solr-data](https://github.com/HGNC/pgnc-ext-solr-data): Persistant volume for the Solr search.
- [pgnc-solr-client](https://github.com/HGNC/pgnc-solr-client): A thin server side client to allow the website to interact with the search server without exposing it to the outside world.
- [pgnc_solr_load](https://github.com/HGNC/pgnc_solr_load): Runs only on startup. Connects to the DB and Solr and fills Solr with indexed data from the DB.
- [pgnc_db_schema](https://github.com/HGNC/pgnc_db_schema): Persistant volume for the DB. Also contains the gzipped data that is loaded during startup.
- [pgnc-ext-nginx](https://github.com/HGNC/pgnc-ext-nginx): Reverse proxy and load balancer for the external-facing components of the PGNC stack.

## Installation

```bash
# Clone the repository
git clone --recursive https://github.com/HGNC/pgnc-external-stack.git;
# Enter the project directory
cd pgnc-external-stack;
# Run using docker compose
docker compose up -d
# Or use podman compose
podman compose up -d
```

The site should be available at <http://localhost:8080>

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
