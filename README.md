# odoo_async

Aplicación Flutter para escritorio con sincronización Odoo.

## Requisitos

- Flutter 3.11+ instalado
- SDK de macOS activado para Flutter: `flutter config --enable-macos-desktop`
- SDK de Windows activado para Flutter: `flutter config --enable-windows-desktop` (desde Windows)
- `flutter pub get` ejecutado antes de compilar

## Compilar para macOS

Desde macOS, en la raíz del proyecto:

```bash
flutter clean
flutter pub get
flutter build macos --release
```

El binario generado estará en:

```text
build/macos/Build/Products/Release/odoo_async.app
```

### Nota importante sobre la apertura en macOS

El proyecto usa `window_manager` y `tray_manager` para gestionar la ventana nativa y el icono de bandeja.
En esta configuración, el app se abre siempre visible en release y el botón `X` cierra la aplicación normalmente.

Para probar la UI visible en macOS, usa:

```bash
flutter run -d macos
```

Si prefieres cambiar el comportamiento y hacer que la app se oculte en la bandeja al cerrar la ventana, ajusta `lib/core/services/window_tray_service.dart`.

## Compilar para Windows

La compilación de Windows debe realizarse en un host Windows.

```bash
flutter clean
flutter pub get
flutter build windows --release
```

El ejecutable generado estará en:

```text
build/windows/runner/Release/odoo_async.exe
```

## Empaquetar un `.dmg` en macOS

Una vez generado `odoo_async.app`, crea un instalador `.dmg` con `hdiutil`:

```bash
cd build/macos/Build/Products/Release
hdiutil create -volname "OdooDesktopSync" -srcfolder odoo_async.app -ov -format UDZO odoo_async.dmg
```

Esto generará `odoo_async.dmg` en el mismo directorio.

## Notas adicionales

- Si el icono de bandeja no aparece en Windows, agrega `assets/images/app_icon.ico`.
- El archivo `assets/images/app_icon.png` se usa actualmente para macOS.
- Para depuración rápida, `flutter run -d macos` es la forma más efectiva de comprobar que la UI se carga correctamente.
