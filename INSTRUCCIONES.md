# Proyecto Desktop Java + React + JCEF

## Objetivo

Crear una aplicación desktop moderna que:

1. Lea archivos Excel desde una carpeta
2. Concatene la información
3. Muestre los datos en una tabla
4. Permita seleccionar múltiples registros
5. Envíe los registros seleccionados a una API REST

---

# Arquitectura

```text
Desktop App
│
├── Swing JFrame
│       └── JCEF Browser
│               └── React Frontend
│
└── Spring Boot Backend
        ├── Lectura Excel
        ├── API REST
        ├── Procesamiento
        └── Integración HTTP
```

---

# Patrones de Diseño y Buenas Prácticas

Toda la aplicación, en sus tres capas (Backend, Frontend, Desktop), debe desarrollarse aplicando fuertemente:

*   **Principios SOLID**: Responsabilidad única (SRP), Abierto/Cerrado (OCP), Sustitución de Liskov (LSP), Segregación de Interfaces (ISP) e Inversión de Dependencias (DIP).
*   **Clean Architecture**: Separación clara entre modelos de dominio, casos de uso (servicios), adaptadores (controladores/repositorios) y la infraestructura.
*   **Patrones de Diseño**: Uso de patrones como Factory, Singleton, Observer o Strategy donde aplique para mantener el código escalable y mantenible.

---

# Tecnologías

## Backend

* Java 21
* Spring Boot 3
* Apache POI
* Jackson
* OkHttp o WebClient

## Frontend

* React
* Vite
* Axios
* AG Grid
* TailwindCSS (Estilos)
* Lucide-React (Íconos)

## Desktop

* Swing
* JCEF

---

# Estructura del Proyecto

```text
project-root/
│
├── backend/
│   ├── src/main/java/
│   └── pom.xml
│
├── frontend/
│   ├── src/
│   └── package.json
│
└── desktop/
    ├── src/main/java/
    └── pom.xml
```

---

# Flujo de la Aplicación

## 1. Backend

Spring Boot:

* escanea carpeta
* lee excels
* concatena registros
* expone REST API

Endpoints:

```text
GET  /api/files/load
GET  /api/items
POST /api/items/send
```

---

## 2. Frontend React

Pantallas y Módulos:

### 1. Módulo de Login
* Formulario de autenticación para asegurar el acceso a la app o validar credenciales de Odoo.

### 2. Módulo de Dashboard
* Vista principal con métricas, resumen de archivos procesados y estado de la sincronización.

### 3. Módulo Seleccionador de Archivos Excel
* Interfaz para seleccionar los archivos Excel específicos que se van a unir.
* Opción para **activar o desactivar** archivos individuales (ignorar archivos inactivos durante la concatenación).
* Tabla principal con filtros y selección múltiple de registros.
* Botón enviar a la API de Odoo.

---

## 3. Desktop Java

Swing:

```java
JFrame
```

Contenedor Chromium:

```java
CefBrowser
```

Carga:

```text
http://localhost:3000
```

---

# Dependencias Backend

## Apache POI

Leer Excel:

```xml
<dependency>
    <groupId>org.apache.poi</groupId>
    <artifactId>poi-ooxml</artifactId>
    <version>5.2.5</version>
</dependency>
```

---

# Lectura de Excel

## Objetivo

Leer todos los:

```text
*.xlsx
```

de una carpeta:

```text
C:/excel/
```

---

## Flujo

```text
carpeta
    ↓
listar archivos
    ↓
leer excel
    ↓
mapear filas
    ↓
concatenar
    ↓
retornar JSON
```

---

# Modelo de Datos

```java
public class ExcelItem {

    private String codigo;
    private String descripcion;
    private Double cantidad;
    private Boolean selected;

}
```

---

# API REST

## Obtener datos

```java
@GetMapping("/api/items")
```

Respuesta:

```json
[
  {
    "codigo": "P001",
    "descripcion": "Producto",
    "cantidad": 10
  }
]
```

---

## Enviar seleccionados

```java
@PostMapping("/api/items/send")
```

Body:

```json
[
  {
    "codigo": "P001"
  }
]
```

---

# Frontend React

## Tabla e Interfaz

Usar AG Grid para la tabla, TailwindCSS para los estilos y Lucide-React para íconos:

```bash
npm install ag-grid-react ag-grid-community lucide-react
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

---

# Características UI

## Tabla e Interfaz

* checkbox selección de registros
* switch / toggle para activar o desactivar archivos completos
* filtros
* búsqueda
* paginación
* columnas dinámicas

---

# Flujo Frontend

```text
React
    ↓
Axios GET /api/items
    ↓
Mostrar tabla
    ↓
Usuario selecciona
    ↓
Axios POST /api/items/send
```

---

# Comunicación Frontend ↔ Backend

## Axios

```bash
npm install axios
```

---

# JCEF

## Objetivo

Embebir Chromium dentro de Swing.

---

# Flujo Desktop

```text
JFrame
    ↓
JCEF Browser
    ↓
React UI
```

---

# Inicializar Spring Boot desde Desktop

La app desktop puede iniciar el backend automáticamente:

```java
SpringApplication.run(App.class);
```

---

# Inicializar React

Opciones:

## Desarrollo

React:

```text
localhost:5173
```

## Producción

Compilar React:

```bash
npm run build
```

y servir estáticos desde Spring Boot.

---

# Flujo Completo

```text
Desktop inicia
    ↓
Spring Boot inicia
    ↓
JCEF abre React
    ↓
Backend lee Excel
    ↓
Frontend muestra tabla
    ↓
Usuario selecciona
    ↓
Enviar API externa
```

---

# Librerías Recomendadas

## Backend

* Spring Boot
* Apache POI
* Lombok

## Frontend

* React
* AG Grid
* Axios

## Desktop

* JCEF
* Swing

---

# Funcionalidades Futuras

* Drag and drop Excel
* Configuración API
* Login
* SQLite local
* Logs
* Modo oscuro
* Cola de envío
* Reintentos
* Exportar errores

---

# Objetivo Final

Construir una aplicación desktop moderna similar a:

* Chat2DB
* DBeaver
* Postman

pero orientada a:

* procesamiento Excel
* selección masiva
* envío API
* monitoreo de cargas

# Compilación y Generación de Instalador .EXE

## Objetivo

Generar:

* aplicación Windows `.exe`
* instalador profesional
* ejecutable standalone
* instalación con accesos directos

---

# Arquitectura Final

```text id="a8s2wn"
Java Desktop
    +
JCEF
    +
Spring Boot
    +
React
    ↓
Generar EXE
    ↓
Instalador Windows
```

---

# Requisitos

## Instalar

### Java JDK 21

Descargar:

```text id="k9z7xp"
https://adoptium.net
```

---

## Maven

Verificar:

```bash id="b7v5tu"
mvn -version
```

---

## Node.js

Verificar:

```bash id="y3w6nk"
node -v
```

---

# Compilar Frontend React

Ir a:

```text id="a1q9dx"
frontend/
```

Instalar:

```bash id="m5k4fj"
npm install
```

Compilar:

```bash id="x6c8pw"
npm run build
```

Generará:

```text id="q1r8eh"
frontend/dist
```

---

# Integrar React con Spring Boot

Copiar:

```text id="z7d5tv"
frontend/dist
```

a:

```text id="g4p1xs"
backend/src/main/resources/static
```

Spring Boot servirá React automáticamente.

---

# Compilar Backend

Ir a:

```text id="x9h6qb"
backend/
```

Compilar:

```bash id="u2v7yc"
mvn clean package
```

Generará:

```text id="s8k3zr"
target/app.jar
```

---

# Empaquetar Desktop

## Maven Shade Plugin

Crear ejecutable único:

```xml id="r6m9pt"
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-shade-plugin</artifactId>
</plugin>
```

---

# Generar Runtime Java Embebido

Usar:

```bash id="c3f8la"
jlink
```

Crear runtime mínimo:

```bash id="e7x4nm"
jlink --add-modules java.base,java.desktop,java.sql \
      --output runtime
```

---

# Crear EXE

## Opción recomendada: jpackage

Java 21 incluye:

```text id="w2q8mb"
jpackage
```

---

# Generar EXE

Ejemplo:

```bash id="n4d7tx"
jpackage ^
  --type exe ^
  --name OdooDesktopSync ^
  --input target ^
  --main-jar app.jar ^
  --main-class com.app.Main ^
  --runtime-image runtime ^
  --win-menu ^
  --win-shortcut ^
  --icon app.ico
```

---

# Resultado

Generará:

```text id="j6v1ka"
OdooDesktopSync.exe
```

e instalador Windows.

---

# Instalador Profesional

## Opciones

| Herramienta | Recomendado |
| ----------- | ----------- |
| jpackage    | ✅           |
| Inno Setup  | ✅           |
| NSIS        | ✅           |
| Launch4j    | Opcional    |

---

# Recomendación

## Usar:

### jpackage + Inno Setup

---

# Instalador con Inno Setup

## Descargar

```text id="n9k5cp"
https://jrsoftware.org/isinfo.php
```

---

# Script Instalador

Ejemplo:

```ini id="d8q2vw"
[Setup]
AppName=Odoo Desktop Sync
AppVersion=1.0
DefaultDirName={pf}\OdooDesktopSync

[Files]
Source: "OdooDesktopSync.exe"; DestDir: "{app}"

[Icons]
Name: "{group}\Odoo Desktop Sync"; Filename: "{app}\OdooDesktopSync.exe"
```

---

# Crear EXE Portable

También puedes generar:

```text id="j1r9by"
OdooDesktopSync.exe
```

sin instalador.

---

# Estructura Final

```text id="p7w4mx"
release/
│
├── OdooDesktopSync.exe
├── runtime/
├── app/
└── config/
```

---

# Configuración Externa

Crear:

```text id="z5t2ha"
config.json
```

Ejemplo:

```json id="t8m6pn"
{
  "excelPath": "C:/excel",
  "apiUrl": "https://api.miempresa.com"
}
```

---

# Logs

Guardar logs:

```text id="n2c8xy"
logs/app.log
```

Usar:

* Logback
* SLF4J

---

# Actualizaciones Futuras

Se puede agregar:

* auto updater
* instalación automática
* actualización remota
* firma digital
* splash screen

---

# Flujo Final de Build

```text id="e3u7lf"
React build
    ↓
Spring Boot package
    ↓
Desktop package
    ↓
jlink runtime
    ↓
jpackage exe
    ↓
Inno Setup installer
```

---

# Resultado Esperado

El usuario podrá:

1. Descargar instalador
2. Instalar aplicación
3. Abrir aplicación desktop
4. Leer excels
5. Seleccionar registros
6. Enviar API

Todo sin instalar Java manualmente.

---

# Comandos para Crear el Proyecto

A continuación, los comandos paso a paso para inicializar la estructura base de este proyecto:

## 1. Crear Directorio Raíz

```bash
mkdir odoo_desktop_sync
cd odoo_desktop_sync
```

## 2. Inicializar Frontend (React + Vite)

```bash
npm create vite@latest frontend -- --template react
cd frontend
npm install
npm install axios ag-grid-react ag-grid-community lucide-react
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
cd ..
```

## 3. Inicializar Backend (Spring Boot)

Usando Spring Initializr (via curl):

```bash
curl -G https://start.spring.io/starter.zip -d dependencies=web,lombok -d javaVersion=21 -d type=maven-project -d bootVersion=3.2.5 -o backend.zip
unzip backend.zip -d backend
rm backend.zip
```
*(Luego, agregar las dependencias de Apache POI en el pom.xml del backend como se indica arriba)*

## 4. Inicializar Desktop (Java Swing + JCEF)

Se puede usar un arquetipo Maven básico para la base:

```bash
mvn archetype:generate -DgroupId=com.desktop -DartifactId=desktop -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false
```

*(Luego configurar el maven-shade-plugin e incluir las dependencias de JCEF como se discutió)*

---

# Orquestación de Creación con Agentes de IA

Para desarrollar este sistema de forma modular, ágil y colaborativa usando múltiples agentes de IA (o múltiples sesiones/prompts), se proponen los siguientes **Roles y Responsabilidades**:

## 1. 🏗️ Arquitecto / Project Manager (Agente Líder)
**Responsabilidad:** Definir la arquitectura general basándose en principios SOLID y Clean Architecture, establecer contratos de API, estructura de carpetas y coordinar el trabajo de los demás agentes.
*   **Prompt inicial sugerido:** "Eres el Arquitecto de Software. Diseña el sistema siguiendo principios SOLID y Clean Architecture. Define el contrato JSON exacto que el Backend enviará al Frontend y revisa que los comandos de build final (`jlink` + `jpackage`) estén correctamente definidos para unir todos los módulos."
*   **Tareas:**
    *   Definir estructura del `config.json` y los lineamientos SOLID del proyecto.
    *   Supervisar la integración de los 3 módulos (Backend, Frontend, Desktop).

## 2. ⚙️ Agente Backend (Experto Java & Spring Boot)
**Responsabilidad:** Construir la API REST y la lógica de procesamiento de Excel.
*   **Prompt inicial sugerido:** "Eres el Desarrollador Backend. Tienes la tarea de implementar la lectura de una carpeta con archivos `.xlsx` usando Apache POI, concatenar los datos y exponerlos vía un endpoint GET en Spring Boot."
*   **Tareas:**
    *   Implementar modelo `ExcelItem`.
    *   Implementar servicio con Apache POI para escanear y leer archivos.
    *   Crear los controladores `@RestController` para `/api/items` y `/api/items/send`.

## 3. 🎨 Agente Frontend (Experto React & Vite)
**Responsabilidad:** Construir la interfaz de usuario que corre dentro de Chromium.
*   **Prompt inicial sugerido:** "Eres el Desarrollador Frontend. Crea un Dashboard en React usando Vite, aplicando TailwindCSS para los estilos y Lucide-React para la iconografía. Usa AG Grid para la tabla de datos. Debe consumir el endpoint `/api/items`, mostrar una tabla con selección de checkboxes y un botón para enviar los registros seleccionados vía POST."
*   **Tareas:**
    *   Crear la tabla principal dinámica.
    *   Integrar Axios para conectar con el backend.
    *   Estilizar la aplicación con TailwindCSS siguiendo buenas prácticas de UI, pensando en una vista de software de escritorio.

## 4. 🖥️ Agente Desktop (Experto Java Swing & JCEF)
**Responsabilidad:** Construir el contenedor nativo de escritorio y compilar la aplicación.
*   **Prompt inicial sugerido:** "Eres el Desarrollador Desktop. Configura un `JFrame` de Java Swing e integra JCEF para embeber una vista de Chromium que apunte a `localhost:5173` (en desarrollo). Configura el inicio de Spring Boot desde el método `main` de la app de Swing."
*   **Tareas:**
    *   Configurar dependencias nativas de JCEF.
    *   Crear la ventana (JFrame) integrando el navegador.
    *   Garantizar que al cerrar la ventana, se cierren correctamente el servidor Spring Boot y Chromium.

## 5. 🚀 Agente DevOps / Empaquetado
**Responsabilidad:** Generar el instalador final `.exe` para Windows.
*   **Prompt inicial sugerido:** "Eres el Ingeniero DevOps. Toma los JAR compilados, el frontend empaquetado y utiliza `jlink` y `jpackage` para crear un instalador .exe standalone que no requiera tener Java instalado."
*   **Tareas:**
    *   Crear script automatizado (batch/sh) del flujo completo de compilación.
    *   Escribir el archivo de configuración para Inno Setup.
