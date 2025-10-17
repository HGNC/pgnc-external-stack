FROM ghcr.io/hgnc/pgnc-solr:latest

USER root
COPY solr/cores/data /var/solr/data
RUN chown -R solr:solr /var/solr/data
USER solr