FROM postgres:17.0

COPY db-data/docker-entrypoint-initdb.d /docker-entrypoint-initdb.d