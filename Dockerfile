FROM ubuntu:24.04
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -qq install -y --no-install-recommends openjdk-21-jdk curl tmux

RUN mkdir -p /opt/minecraft
WORKDIR /opt/minecraft
RUN curl https://api.purpurmc.org/v2/purpur/1.21/latest/download -o purpur-1.21.jar
RUN java -jar /opt/minecraft/purpur-1.21.jar --nogui \
    && sed -i s/eula=false/eula=true/ eula.txt
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh 
COPY run.sh /run.sh
RUN chmod +x /run.sh 

RUN apt-get -y remove curl \
    && apt-get -y autoremove \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash","/entrypoint.sh"]
CMD ["start"]
