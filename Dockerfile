FROM itzg/minecraft-server:latest
USER root
COPY --chown=1000:1000 plugins/ /plugins/
