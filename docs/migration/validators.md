# Validadores y Reglas de Migración de UI

Este documento contiene las reglas de validación técnicas y de diseño que **deben cumplirse estrictamente** durante el proceso de migración progresiva a Forui. El Agente Validador de Calidad utilizará esta lista como checklist de aprobación.

---

## 🛠️ Validaciones de API de Widgets

Las siguientes sustituciones deben ser verificadas detalladamente, ya que las APIs difieren de las de Material Design:

### 1. Botones (`FButton`)
*   **Reemplazo**: `ElevatedButton`, `TextButton`, `OutlinedButton`, `FilledButton` ➡️ `FButton`.
*   **Propiedad de Callback**: En `FButton`, el evento de pulsado es **`onPress`**, no `onPressed`.
    *   *Incorrecto*: `FButton(onPressed: () {}, ...)`
    *   *Correcto*: `FButton(onPress: () {}, ...)`
*   **Variantes**: Usar el parámetro `label` o pasar el texto directamente en el `child`. Si se necesita variante destructiva (como "Limpiar Logs"), usar:
    *   `FButton(variant: FButtonVariant.destructive, onPress: ..., child: Text('Eliminar'))`

### 2. Cuadros de Texto (`FTextField`)
*   **Reemplazo**: `TextField`, `TextFormField` ➡️ `FTextField`.
*   **Estructura**: En Forui, el `FTextField` incluye soporte nativo de etiquetas descriptivas e indicadores de error sin necesidad de envolverlo de forma manual.
    *   Usar `label: Text('SSID')` y `description: Text('Nombre de red')` para una presentación consistente.

### 3. Diálogos (`FDialog`)
*   **Reemplazo**: `showDialog()` + `AlertDialog` ➡️ `showFDialog()` + `FDialog`.
*   *Nota*: No olvides usar la llamada de Forui `showFDialog` para asegurar que el overlay y las animaciones correspondan al sistema de diseño.

### 4. Insignias de Estado (`FBadge`)
*   **Reemplazo**: Contenedores custom con decoraciones ➡️ `FBadge`.
*   **Variantes**: Utilizar las variantes integradas para estados:
    *   `FBadge(child: Text('ACTIVO'))` con estilo o variante correspondiente (ej. semánticos).

### 5. Iconos (`FLucideIcons`)
*   **Reemplazo**: `Icons.*` (Material Icons) ➡️ `FLucideIcons.*` (Lucide Icons).
*   **Import**: Los iconos Lucide vienen incluidos en el paquete `forui`.
    *   *Ejemplo*: `Icon(FLucideIcons.wifi)` en lugar de `Icon(Icons.wifi)`.

### 6. Barra de Navegación Lateral (`FSidebar`)
*   **Reemplazo**: Pestañas o layouts centrados ➡️ `FSidebar` integrado en `FScaffold.sidebar`.
*   **API del Item**: El callback de click en `FSidebarItem` es **`onPress`**, no `onPressed`.
    *   *Correcto*: `FSidebarItem(label: Text('Logs'), onPress: () {})`
*   **API del Grupo**: El callback de acción en `FSidebarGroup` es **`onActionPress`**, no `onActionPressed`.
    *   *Correcto*: `FSidebarGroup(label: Text('Dispositivos'), action: Icon(FLucideIcons.plus), onActionPress: () {})`
*   **Interactividad**: El estado de selección debe rastrearse explícitamente pasando `selected: true` en el `FSidebarItem` activo.

### 7. Comandos y Generación de CLI
*   **Regla**: Para crear personalizaciones de estilos o temas para toda la aplicación, **SIEMPRE** se deben preferir las herramientas integradas del CLI de Forui:
    *   *Listar estilos*: `dart run forui style ls`
    *   *Crear personalización de estilo*: `dart run forui style create <style-name>`
    *   *Crear personalización de tema*: `dart run forui theme create <theme-template>`
*   Esto previene lints y código inconsistente con el framework.

---

## 🖥️ Adaptación Exclusiva para Escritorio (Desktop Constraints)

Dado que la aplicación es exclusivamente para uso en **computadoras de escritorio** (Windows y macOS), se deben aplicar las siguientes validaciones de adaptación:

1.  **Variación del Tema**:
    *   **Obligatorio**: Configurar siempre el tema en su versión `.desktop`.
    *   *Ejemplo*: `FThemes.neutral.light.desktop` o `FThemes.neutral.dark.desktop`.
    *   **Prohibido**: Utilizar variantes `.touch`, ya que sobredimensionan las áreas interactivas para dedos de pantallas móviles.
2.  **Densidad de Spacing**:
    *   El espaciado vertical y horizontal debe ser compacto para optimizar el espacio de pantalla del monitor.
    *   Utilizar la propiedad `spacing` de layouts lineales en lugar de anidar múltiples `SizedBox` de gran tamaño.
3.  **Comportamiento de Cursor**:
    *   Todos los botones y áreas de interacción (`FButton`, tiles, etc.) deben reaccionar al estado *Hover* del mouse y mostrar el cursor correcto (generalmente `SystemMouseCursors.click`).
4.  **Uso de Resizable**:
    *   Para vistas divididas o paneles laterales, utilizar el widget `FResizable` en lugar de anchos estáticos harcodeados. Esto proporciona una UX nativa de escritorio excelente.

---

## 🔍 Checklist de Validación (Flutter Analyze)

Antes de fusionar o dar por finalizada la migración de cualquier archivo:
- [ ] No debe haber advertencias de imports no utilizados (`unused_import`).
- [ ] No debe haber errores de tipos (ej. pasar `onPressed` en vez de `onPress`).
- [ ] Todos los widgets deben compilar sin advertencias en la consola.
- [ ] La aplicación debe pasar el análisis estático (`flutter analyze` finalizado con éxito).
