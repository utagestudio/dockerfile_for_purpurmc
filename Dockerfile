FROM ubuntu:24.04
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -qq install -y --no-install-recommends openjdk-21-jdk curl tmux

ARG VERSION
ENV VERSION=${VERSION}

RUN mkdir -p /opt/minecraft
WORKDIR /opt/minecraft
RUN curl https://api.purpurmc.org/v2/purpur/${VERSION}/latest/download -o purpur-${VERSION}.jar
RUN java -jar /opt/minecraft/purpur-${VERSION}.jar --nogui

RUN apt-get -y remove curl \
    && apt-get -y autoremove \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/bin/bash","/entrypoint.sh"]
CMD ["start"]
