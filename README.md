# RouteGuard iOS Native App (`SwiftUI` + `SwiftData`)

Aplicación móvil nativa para iOS desarrollada en **Swift 5.10 / SwiftUI (iOS 17+)** para la gestión y monitoreo en tiempo real de movilidad escolar segura, conectada al backend RESTful `routeguard-web-services` en Render + PostgreSQL.

## Arquitectura y Persistencia Dual
- **Preferencias ligeras (`UserDefaults` — `SessionStore`)**: token JWT, rol activo (`PARENT`, `DRIVER`, `ADMINISTRATOR`), preferencia de idioma (`es` / `en`) y Modo Oscuro.
- **Persistencia offline estructurada (`SwiftData` SQLite — `LocalDatabase`)**: caché y cola de sincronización (`pendingSync`) para foto de perfil en base64, documentación vehicular SOAT, cuidadores autorizados, tickets de soporte, ausencias tempranas, historial/calificaciones, mantenimientos (`US-20`), foro de anuncios (`US-24`), gastos operativos (`US-26`), cambios temporales y paradas optimizadas (`US-27`, `US-28`) y chat interno (`US-30`).
- **Mapas nativos (`MapKit`)**: seguimiento geoespacial en vivo y vista operativa del conductor.

## Pruebas y CI en GitHub Actions (`macos-latest`)
Este repositorio utiliza **`XcodeGen`** (`project.yml`) y el flujo `.github/workflows/ios-ci.yml` sobre `macos-latest` para:
1. Generar `RouteGuard.xcodeproj` automáticamente (`xcodegen generate`).
2. Ejecutar las pruebas unitarias (`RouteGuardTests`) y pruebas UI (`RouteGuardUITests`) en el Simulador de iPhone.
3. Exportar como artefacto el paquete `.app` de iOS Simulator y las capturas de pantalla del simulador.

## Compilar en macOS localmente
```bash
brew install xcodegen
xcodegen generate
open RouteGuard.xcodeproj
```
