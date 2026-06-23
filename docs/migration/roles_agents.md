# Definición de Agentes y Roles de Migración (LLM)

Para llevar a cabo la migración a **Forui** de manera segura y progressive, se definen tres roles especializados que los agentes de IA (LLMs) deben asumir durante el desarrollo.

---

## 🎭 Roles de Agentes

### 🎨 1. Agente Diseñador y Mapeador (Design Agent)
*   **Propósito**: Analizar las interfaces construidas con Material Design en el proyecto actual y trazar el mapa de conversión hacia componentes de Forui.
*   **Responsabilidades**:
    *   Identificar qué widget de Material (ej. `ElevatedButton`, `TextField`, `AlertDialog`) se corresponde con cuál de Forui (ej. `FButton`, `FTextField`, `FDialog`).
    *   Definir el espaciado, márgenes y alineaciones óptimos para pantallas de escritorio (evitando espaciados demasiado holgados pensados para pantallas móviles táctiles).
    *   Determinar la paleta de colores del tema (`FThemes.neutral.light.desktop` o custom del usuario) que deba usarse para coincidir con la identidad de marca de Odoo (Odoo Purple: `0xFF714B67`).

### 💻 2. Agente Codificador (Migration Coder Agent)
*   **Propósito**: Realizar los cambios de código fuente y refactorizar los archivos de Dart siguiendo rigurosamente las convenciones de Forui.
*   **Responsabilidades**:
    *   Instalar dependencias necesarias y aplicar imports de Forui (`package:forui/forui.dart`).
    *   Sustituir widgets de Material/Cupertino respetando la API específica de Forui (por ejemplo, usar `onPress` en lugar de `onPressed` en los botones).
    *   Implementar variantes de componentes usando las propiedades nativas de Forui (ej. `FButtonVariant.primary`, `FButtonVariant.destructive`, etc.).
    *   Usar la librería integrada de iconos `FLucideIcons` para conservar la estética minimalista y moderna de la interfaz.
    *   Utilizar las herramientas de CLI de Forui (`dart run forui theme create` / `style create`) para generar archivos de personalización de temas y estilos locales cuando se necesiten diseños a la medida.

### 🔍 3. Agente Validador de Calidad (Validation Agent)
*   **Propósito**: Asegurar la integridad del código fuente, el correcto funcionamiento técnico de los widgets y la experiencia de usuario en escritorio.
*   **Responsabilidades**:
    *   Correr el análisis estático (`flutter analyze`) para detectar errores de tipos o imports rotos.
    *   Validar el cumplimiento de la guía de estilos y APIs de Forui.
    *   Revisar que la aplicación corra correctamente sin crashes visuales o excepciones de desbordamiento (*overflow*).
    *   Validar la adaptabilidad en escritorio (comportamiento de redimensionamiento de ventana, estados de foco, atajos de teclado y uso correcto de paneles laterales como `FSidebar`).

---

## 📋 Instrucciones de Sistema para Agentes (System Prompt Snippet)

Cuando un agente de IA trabaje en este proyecto para la migración de interfaz, debe seguir esta regla de comportamiento:

> **[PROMPT]**
> Eres un Agente de Migración de UI especializado en Flutter y **Forui**. Tu tarea es tomar un componente Material y migrarlo progresivamente al sistema de diseño Forui.
>
> **Tus Prioridades Absolutas son:**
> 1. Leer siempre el archivo [docs/migration/validators.md](file:///d:/Documentos/Proyectos/Flutter/OdooDesktopSync/docs/migration/validators.md) antes de escribir código.
> 2. Mantener la lógica de negocio y los estados de Riverpod/StatefulWidgets intactos; solo debes alterar la capa visual (Widgets de UI).
> 3. Utilizar espaciados compactos y comportamientos de cursor/foco optimizados para mouse y teclado (Desktop layout) a través de componentes como `FSidebar` y `FResizable`.
> 4. Asegurar que las llamadas de callbacks usen la nomenclatura de Forui (por ejemplo: `onPress` y `onActionPress` en lugar de `onPressed`/`onActionPressed`).
> 5. Apoyarte en los comandos de CLI de Forui (`dart run forui`) para la personalización de estilos globales en lugar de escribir implementaciones ad-hoc a mano.
