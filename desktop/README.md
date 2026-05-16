# Odoo Desktop Sync - Módulo Desktop

Este módulo es la envoltura nativa de la aplicación. Utiliza **Java Swing** y **JCEF** (Java Chromium Embedded Framework) para embeber un navegador web completo y mostrar la interfaz construida en React, servida por Spring Boot.

## 🚀 Requisitos

- Java JDK 21
- Maven

*Nota: La primera vez que se ejecute la aplicación, JCEF descargará automáticamente los binarios de Chromium necesarios para tu sistema operativo en una carpeta local llamada `jcef-bundle`.*

---

## 💻 Cómo compilar y ejecutar (Desarrollo)

Para probar este módulo de manera independiente, puedes usar el plugin de Maven Exec:

1. Navega a la carpeta `desktop`:
   ```bash
   cd desktop
   ```
2. Compila y ejecuta:
   ```bash
   mvn clean compile exec:exec
   ```

*(Nota técnica: Se usa `exec:exec` en lugar de `exec:java` para poder pasar correctamente los argumentos de JVM `--add-exports` requeridos por JCEF y macOS en versiones de Java > 16).*

### Interacción con el Backend

El método `main` de `App.java` intenta iniciar automáticamente el Backend (`app.jar`) si lo encuentra:
1. Busca un archivo `app.jar` en el mismo directorio.
2. Si no lo encuentra, busca en `../backend/target/app.jar` (útil si ya corriste `mvn clean package` en el backend).
3. Si lo encuentra, lo inicia como un subproceso (`ProcessBuilder`) y la ventana de Chrome cargará `http://localhost:8080`.
4. Si **NO** encuentra el JAR, asume que tú arrancaste el servidor de React o Spring Boot manualmente en otra terminal y simplemente abre la ventana apuntando a `http://localhost:8080`.

---

## 📖 Manual de Uso

Cuando la aplicación inicia:
1. Verás una ventana nativa del sistema operativo con el título **"Odoo Desktop Sync"**.
2. Todo el contenido dentro de la ventana es renderizado utilizando el motor **Chromium** (es idéntico a usar Google Chrome).
3. Puedes interactuar con la interfaz gráfica (React) normalmente.
4. **Al cerrar la ventana** presionando la 'X', el programa interceptará el evento para:
   - Limpiar la memoria gráfica y cerrar el motor Chromium (`CefApp.dispose()`).
   - Terminar el proceso de Spring Boot si fue iniciado automáticamente por el Desktop.

## 🛠 Solución de Problemas

- **Pantalla blanca / Error de conexión**: Significa que JCEF inició correctamente pero no pudo encontrar el servidor en `localhost:8080`. Asegúrate de que el Backend esté corriendo, o modifica la URL en `App.java` si estás usando el puerto de Vite (`5173`).
- **Error descargando JCEF**: Si tu conexión es inestable, JCEF podría fallar al descargar los binarios. Borra la carpeta `jcef-bundle` generada e intenta de nuevo.
