# Plan de Migración Progresiva a Forui

Este documento define la estrategia paso a paso para migrar la interfaz gráfica de **OdooDesktopSync** desde widgets clásicos de Material Design hacia la biblioteca minimalista **Forui** (https://forui.dev), optimizando el diseño específicamente para entornos de escritorio (Windows/macOS).

---

## Cronograma de Fases

### 📌 Fase 1: Configuración de la Fundación (CLI, Main & Temas)
*   **Objetivo**: Establecer Forui en el proyecto mediante su CLI, configurar el árbol de widgets, la localización y el tema optimizado.
*   **Tareas**:
    *   Asegurar que `forui` y `forui_assets` estén en `pubspec.yaml` (Listo).
    *   Ejecutar `dart run forui init` para inicializar el archivo de configuración `forui.yaml`.
    *   (Opcional) Ejecutar `dart run forui theme create` para generar un tema personalizado en `lib/theme/theme.dart` si se requiere ajustar la paleta neutral con el color Odoo Purple (`0xFF714B67`).
    *   Modificar [main.dart](file:///d:/Documentos/Proyectos/Flutter/OdooDesktopSync/lib/main.dart) para envolver la aplicación (`builder`) con `FTheme`, `FToaster` y `FTooltipGroup`.
    *   Configurar la localización de Forui (`FLocalizations.supportedLocales` y `FLocalizations.localizationsDelegates`).
    *   Configurar el tema por defecto adaptado para escritorio: `FThemes.neutral.light.desktop` y `FThemes.neutral.dark.desktop`.

### 📌 Fase 2: Migración de Componentes Simples (Widgets Auxiliares)
*   **Objetivo**: Adaptar widgets aislados a Forui para validar el sistema de diseño.
*   **Tareas**:
    *   Migrar [status_badge.dart](file:///d:/Documentos/Proyectos/Flutter/OdooDesktopSync/lib/ui/widgets/status_badge.dart) utilizando el widget `FBadge` de Forui.
    *   Migrar [info_card.dart](file:///d:/Documentos/Proyectos/Flutter/OdooDesktopSync/lib/ui/widgets/info_card.dart) utilizando `FCard` de Forui.

### 📌 Fase 3: Migración del Diálogo de Logs
*   **Objetivo**: Migrar el visor de terminal de logs a Forui de forma limpia y moderna.
*   **Tareas**:
    *   Migrar [logs_dialog.dart](file:///d:/Documentos/Proyectos/Flutter/OdooDesktopSync/lib/ui/widgets/logs_dialog.dart) para abrirse mediante `showFDialog` de Forui.
    *   Reemplazar el diseño del diálogo de logs usando `FDialog` (con soporte para títulos, listas y botones de acción tipo `FButton`).
    *   Ajustar el diálogo de confirmación para usar `FDialog` con las variantes semánticas adecuadas para la acción destructiva (Limpiar logs).

### 📌 Fase 4: Migración de la Pantalla Principal (Dashboard con Sidebar)
*   **Objetivo**: Realizar la transición completa de la pantalla principal a un diseño adaptado para escritorio usando una barra de navegación lateral (`FSidebar`) y un contenedor `FScaffold`.
*   **Tareas**:
    *   Reestructurar la pantalla principal usando `FScaffold` y su propiedad `sidebar`.
    *   Implementar un panel lateral izquierdo (`FSidebar`) con grupos (`FSidebarGroup`) e ítems (`FSidebarItem`) para segmentar la interfaz:
        *   **Resumen**: Estado de conexión general y datos del sistema.
        *   **Dispositivos**: Configuración y administración de drivers activos.
        *   **Configuración**: Wi-Fi y base de datos de Odoo.
        *   **Logs**: Botón para abrir el panel de logs.
    *   Migrar los campos de datos y filas (`SingleDataRow`) usando `FTile` y `FTileGroup` de Forui.
    *   Reemplazar todos los botones de acción con `FButton` (usando las propiedades correctas como `onPress`).
    *   Migrar los diálogos de configuración utilizando formularios basados en `FTextField` y `FDialog`.
    *   Optimizar los anchos, márgenes y la interactividad para mouse y teclado (focos y atajos).

---

## Estado Actual de la Migración

- [x] **Fase 1: Preparación** - Añadir dependencia `forui` y `forui_assets`.
- [ ] **Fase 1: Integración** - Integrar `FTheme` en `main.dart`.
- [ ] **Fase 2** - Migración de widgets auxiliares (`StatusBadge`).
- [ ] **Fase 3** - Migración de `LogsDialog`.
- [ ] **Fase 4** - Migración de `DashboardScreen`.
