#!/bin/bash
JAVA_MEMORY_MAX=${JAVA_MEMORY_MAX:8G}
JAVA_MEMORY_MIN=${JAVA_MEMORY_MIN:8G}
java -Xms$JAVA_MEMORY_MIN -Xmx$JAVA_MEMORY_MAX -jar /opt/minecraft/purpur-1.21.jar --nogui

