# Odoo Desktop Sync - Backend

Este es el módulo backend basado en Java y Spring Boot de la aplicación Odoo Desktop Sync. Su objetivo principal es leer archivos `.xlsx` de un directorio, procesarlos y exponer los datos a través de una API REST.

## ⚙️ Configuración (config.json)

El backend requiere un archivo `config.json` ubicado en el directorio de ejecución (por defecto `backend/config.json` si se ejecuta independiente, o en la raíz si se empaqueta). 

Si el archivo no existe, **la aplicación creará uno automáticamente** con los siguientes valores por defecto:

```json
{
  "api": [
    {
      "url": "https://api.miempresa.com",
      "name": "url producion"
    },
    {
      "url": "https://api.miempresa.com",
      "name": "url test"
    }
  ],
  "config_paths": [
    {
      "path": "C:/excel",
      "is_active": true
    },
    {
      "path": "C:/excel_2",
      "is_active": false
    }
  ]
}
```

* **`api`**: Lista de URLs de endpoints externos (por ejemplo, Odoo) a donde se enviarán los datos seleccionados. Solo el primer endpoint o el seleccionado se utilizará.
* **`config_paths`**: Lista de rutas de carpetas donde se buscarán los archivos `.xlsx`. Solo se escanearán aquellas que tengan `is_active: true`.

---

## 🚀 Ejecutar el Backend

Asegúrate de tener Java 21 y Maven instalados.

1. Navega a la carpeta del backend:
   ```bash
   cd backend
   ```
2. Ejecuta la aplicación usando Maven:
   ```bash
   mvn spring-boot:run
   ```

El servidor arrancará en el puerto **8080** (o el que definas en un `application.properties` si lo creas en el futuro).

---

## 🛠 Modo de Uso (Endpoints)

El backend expone la siguiente API REST en la ruta base `/api/items`:

### 1. Cargar datos desde los Excel
**`GET /api/items`**

Lee todos los archivos `.xlsx` que se encuentran en el directorio `excelPath` definido en tu `config.json`. Extrae los datos (suponiendo las columnas `[0]: Código`, `[1]: Descripción`, `[2]: Cantidad`) y retorna un JSON unificado.

**Ejemplo de respuesta:**
```json
[
  {
    "codigo": "P001",
    "descripcion": "Producto A",
    "cantidad": 15.0,
    "selected": true
  },
  ...
]
```

### 2. Enviar datos al sistema externo
**`POST /api/items/send`**

Recibe un Array JSON con los items que han sido seleccionados por el usuario en el Frontend y simula el envío a la `apiUrl` del `config.json`.

**Ejemplo de Body (Raw JSON):**
```json
[
  {
    "codigo": "P001",
    "descripcion": "Producto A",
    "cantidad": 15.0,
    "selected": true
  }
]
```

**Ejemplo de llamada cURL para probar el POST:**
```bash
curl -X POST http://localhost:8080/api/items/send \
  -H "Content-Type: application/json" \
  -d '[{"codigo":"P001","descripcion":"Test","cantidad":10,"selected":true}]'
```

### 3. Gestionar la Configuración
**`GET /api/config`**
Retorna toda la configuración actual cargada en memoria.

**`POST /api/config/api`**
Permite agregar un nuevo endpoint o actualizar uno existente (busca por el campo `name`).
**Body:**
```json
{
  "url": "https://nueva-api.com",
  "name": "url nueva"
}
```

**`POST /api/config/paths`**
Permite agregar una nueva ruta de lectura o actualizar una existente (busca por el campo `path`), por ejemplo, para activar o desactivar una carpeta.
**Body:**
```json
{
  "path": "C:/excel_2",
  "is_active": true
}
```


---

## 📝 Notas para Desarrollo

* **CORS** ya está habilitado para permitir peticiones desde `http://localhost:5173` y `http://localhost:3000` (puertos típicos de React/Vite en desarrollo).
* Se asume que los archivos de Excel no tienen contraseñas y la primera fila actúa como encabezado (se ignora al procesar).
