FROM ubuntu:24.04
RUN apt-get update \
    && apt-get -y upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends openjdk-25-jre curl tmux tzdata zstd jq unzip \
    && apt-get -y autoremove \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/*

# The server jar is downloaded into the volume at runtime (see entrypoint.sh),
# so that switching versions does not require rebuilding the image.
RUN mkdir -p /opt/minecraft
WORKDIR /opt/minecraft

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/bin/bash","/entrypoint.sh"]
CMD ["start"]
