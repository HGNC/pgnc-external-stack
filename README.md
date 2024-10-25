# PGNC External stack

This repository contains the PGNC external stack, which is a collection of containers that are used to run the PGNC external site.

Currently this is only a proof of concept, and is not intended to be used as the final production service.

Please look in the `docker-compose.yml` file for the services that are included in this stack. You will need
to change the DB password in the sql dockerfile and then change the Db password in the `docker-compose.yml` file to match.

Once more development is done, and when containers are ready for production, the images will be pull as prebuilt images from Github.

To build the stack as is, you will need to have Docker and Docker Compose installed on your machine.

**Please remember to change the DB password in the `sql` `Dockerfile` and then change the DB password in the `docker-compose.yml` file to match.**

```bash
git clone --recurse-submodules https://github.com/HGNC/pgnc-external-stack.git
# make alterations to the sql Dockerfile and docker-compose.yml file
docker-compose up
```
