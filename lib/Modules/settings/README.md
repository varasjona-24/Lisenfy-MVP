# 📋 Settings Module - Listenfy

Módulo completo de configuración para la aplicación Listenfy.

## 🎯 Características

### 🎨 Apariencia
- **Selector de Modo**: Claro (☀️) y Oscuro (🌙)
- **Selector de Paleta**: 6 paletas de colores predefinidas
  - 🌍 Earth (Tierra)
  - 🌿 Olive (Oliva)
  - 🌊 Blue (Azul)
  - 🌅 Sunset (Atardecer)
  - 🟣 Purple (Púrpura)
  - ⚫ Gray (Gris)

### 🔊 Audio
- **Volumen por defecto**: Slider de 0-100%
- **Reproducción automática**: Toggle para reproducir siguiente canción automáticamente

### 📡 Datos y Descargas
- **Calidad de descarga**: Baja (128 kbps), Media (192 kbps), Alta (320 kbps)
- **Uso de datos**: Solo Wi-Fi o Wi-Fi + móvil
- **Limpiar caché**: Botón para liberar espacio

### ℹ️ Información
- Versión de la app
- Almacenamiento utilizado
- Última fecha de actualización

## 📁 Estructura

```
settings/
├── binding/
│   └── settings_binding.dart         # GetX Binding
├── controller/
│   └── settings_controller.dart      # Lógica de Settings
└── view/
    ├── settings_view.dart            # Vista principal
    └── widgets/
        ├── appearance_section.dart   # Sección de apariencia
        ├── audio_section.dart        # Sección de audio
        ├── data_section.dart         # Sección de datos
        └── about_section.dart        # Sección de información
```

## 🔄 Persistencia de datos

Usa `GetStorage` para guardar las preferencias del usuario:
- `selectedPalette` - Paleta seleccionada
- `brightness` - Modo claro/oscuro
- `defaultVolume` - Volumen por defecto
- `autoPlayNext` - Reproducción automática

## 🚀 Acceso

Desde cualquier parte de la app:
```dart
Get.toNamed(AppRoutes.settings);
```

O mediante el botón de engranaje (⚙️) en la AppBar.

## 🔗 Integración

El módulo está integrado con:
- **ThemeController**: Para cambiar tema y paleta globalmente
- **AppRoutes**: `/settings`
- **AppTopBar**: Botón de acceso rápido

## 📝 Notas

- La persistencia se realiza automáticamente al cambiar cualquier opción
- Los cambios de tema se aplican en tiempo real a toda la aplicación
- El módulo es reutilizable y escalable para agregar nuevas opciones
