FROM ghcr.io/hgnc/pgnc-python:latest

WORKDIR /usr/src/app

COPY python/bin /usr/src/app/bin
COPY db-data/docker-entrypoint-initdb.d /usr/src/app/db-data

RUN chmod +x /usr/src/app/bin/*.sh && \
    mkdir -p /usr/src/app/input /usr/src/app/output