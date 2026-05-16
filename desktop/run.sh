#!/bin/bash
# Script para iniciar la aplicación Desktop en macOS con los argumentos de JVM correctos

cd "$(dirname "$0")"

echo "Compilando y ejecutando Odoo Desktop Sync..."

# Exportar las opciones de JVM necesarias para JCEF en macOS con Java 16+
export MAVEN_OPTS="--add-opens=java.desktop/sun.awt=ALL-UNNAMED --add-opens=java.desktop/sun.lwawt=ALL-UNNAMED --add-opens=java.desktop/sun.lwawt.macosx=ALL-UNNAMED"

# Ejecutar usando exec:exec que lee los argumentos configurados en pom.xml
./mvnw clean compile exec:exec
