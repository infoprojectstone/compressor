# Compresor

Una aplicación nativa para macOS que reúne los compresores de imágenes, vídeo y PDF. Todo se procesa localmente y los originales nunca se modifican.

## Crear la aplicación y los instaladores

- **Compilar y empaquetar en ZIP:**
  ```bash
  zsh scripts/build-app.sh
  ```
  Genera `build/Compressor.app` y `build/Compressor-1.2.zip`.

- **Crear instalador DMG:**
  ```bash
  zsh scripts/create-dmg.sh
  ```
  Genera la imagen de disco lista para distribuir: `build/Compressor-1.2.dmg`.

## Requisitos

- macOS 13 (Ventura) o superior (compatible con Intel y Apple Silicon).
- **Sin dependencias externas:** Todo el procesamiento de imágenes, vídeo y PDF se realiza 100% en local mediante las tecnologías nativas de Apple (ImageIO, CoreGraphics, AVFoundation con aceleración por hardware y PDFKit). No requiere Homebrew, ffmpeg ni librerías adicionales.

## Opciones de compresión

Imágenes, vídeo y PDF comparten dos modos:

- **Calidad:** Alta calidad, Equilibrado o Tamaño pequeño.
- **Tamaño objetivo:** permite indicar un tamaño aproximado por archivo en MB. El resultado puede variar según el contenido y el formato.

Desde Ajustes se puede guardar el resultado en una subcarpeta `Comprimidos` junto al original (opción predeterminada), junto al propio archivo o en una carpeta personalizada. Los originales nunca se sobrescriben y los nombres de salida siempre son únicos.

## Instalación para usuarios (Gatekeeper)

Al ser una aplicación independiente distribuida sin certificado de pago de Apple Developer:
1. Abre el archivo `.dmg` y arrastra **Compressor** a la carpeta **Aplicaciones**.
2. La primera vez que la abras, si macOS muestra el aviso *"no se puede abrir porque Apple no puede comprobar si contiene software malicioso"*:
   - Haz **clic derecho** (o Control + clic) sobre la aplicación en Aplicaciones y selecciona **Abrir**.
   - O bien ve a **Ajustes del Sistema > Privacidad y seguridad** y pulsa en **"Abrir igualmente"**.

