# Odoo Desktop Sync

Aplicación de escritorio moderna construida con Java (Swing + JCEF), Spring Boot y React. Permite leer archivos Excel de un directorio, concatenar la información, visualizarla en una tabla y enviar los registros seleccionados a una API REST de Odoo.

---

## 🛠 Requisitos Previos

Asegúrate de tener instalados en tu sistema:

- **Java JDK 21** (Recomendado: [Adoptium](https://adoptium.net/))
- **Maven** (Verificar con `mvn -version`)
- **Node.js** (Verificar con `node -v`)

---

## 🚀 Instrucciones de Ejecución (Desarrollo)

Para trabajar en el entorno de desarrollo, deberás levantar el servidor del frontend (React) y la aplicación Java por separado.

### 1. Iniciar el Frontend (React + Vite)

Abre una terminal y ejecuta:

```bash
cd frontend
npm install
npm run dev
```

Esto iniciará el servidor de desarrollo de Vite en `http://localhost:5173`.

### 2. Iniciar el Backend / Desktop (Java)

La aplicación Java se encarga de iniciar Spring Boot (Backend) y lanzar la ventana de Swing con JCEF (Desktop) que cargará el puerto del frontend.

```bash
cd backend
mvn clean install
mvn spring-boot:run
```

*(Nota: Dependiendo de cómo esté configurado el orquestador principal en la carpeta `desktop` o `backend`, el comando exacto podría ser sobre el módulo `desktop` usando la clase Main principal).*

---

## 📦 Compilación y Generación de Instalador (.EXE)

Para generar la versión de producción y el ejecutable para Windows sin depender de Java instalado en el cliente, sigue el flujo completo de build:

### 1. Compilar el Frontend

```bash
cd frontend
npm install
npm run build
```
Esto generará los archivos compilados en la carpeta `frontend/dist`.

### 2. Integrar React con Spring Boot

Copia todo el contenido de `frontend/dist` hacia los recursos estáticos del backend para que Spring Boot los sirva:

```bash
# Copiar el contenido al backend
cp -r frontend/dist/* backend/src/main/resources/static/
```

### 3. Compilar el Backend

Genera el JAR de la aplicación:

```bash
cd backend
mvn clean package
```
Esto generará el archivo JAR empaquetado en `target/app.jar`.

### 4. Generar el Runtime Embebido de Java

Usaremos `jlink` para crear un runtime ligero de Java que se empaquetará con la aplicación:

```bash
jlink --add-modules java.base,java.desktop,java.sql --output runtime
```

### 5. Crear el Ejecutable (.exe)

Usando `jpackage` (incluido en Java 21), generamos el instalador standalone de Windows:

```bash
jpackage \
  --type exe \
  --name OdooDesktopSync \
  --input target \
  --main-jar app.jar \
  --main-class com.app.Main \
  --runtime-image runtime \
  --win-menu \
  --win-shortcut \
  --icon app.ico
```

> **Resultado:** Se generará el instalador `OdooDesktopSync.exe` listo para distribuir y ser instalado en cualquier equipo Windows.

---

## ⚙️ Configuración Externa

La aplicación lee su configuración principal desde un archivo `config.json` ubicado junto al ejecutable (o en el directorio de trabajo actual en desarrollo):

```json
{
  "excelPath": "C:/excel",
  "apiUrl": "https://api.miempresa.com"
}
```

## 📝 Logs

Los registros de la aplicación se guardan utilizando Logback/SLF4J en:
`logs/app.log`
