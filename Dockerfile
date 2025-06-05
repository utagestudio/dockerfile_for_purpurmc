FROM ubuntu:24.04 AS downloader
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -qq install --reinstall -y ca-certificates \
    && apt-get -qq install -y --no-install-recommends curl \
    && apt-get -y autoremove \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/*

ARG VERSION
ENV VERSION=${VERSION}

RUN mkdir -p /opt/minecraft
WORKDIR /opt/minecraft
RUN curl https://api.purpurmc.org/v2/purpur/${VERSION}/latest/download -o purpur-${VERSION}.jar


FROM ubuntu:24.04
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -qq install -y --no-install-recommends openjdk-21-jre tmux \
    && apt-get -y autoremove \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/*

ARG VERSION
ENV VERSION=${VERSION}

RUN mkdir -p /opt/minecraft
WORKDIR /opt/minecraft
COPY --from=downloader /opt/minecraft/purpur-${VERSION}.jar /opt/minecraft/
RUN java -jar /opt/minecraft/purpur-${VERSION}.jar --nogui

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/bin/bash","/entrypoint.sh"]
CMD ["start"]
