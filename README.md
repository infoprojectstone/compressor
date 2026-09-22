<div align="center">

  <p>
    <b>Español</b> | <a href="README.en.md">English</a>
  </p>

  <img src="docs/assets/app_icon.png" width="128" height="128" alt="Compressor App Icon" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,0,0,0.3);" />

  # Compressor para macOS
  
  **El compresor nativo definitivo de Imágenes, Vídeo y PDF para tu Mac.**  
  *Local · Aceleración por Hardware · Sin dependencias externas · Privacidad absoluta*

  [![macOS 14+](https://img.shields.io/badge/macOS-Golden%20Gate%20%7C%20Sequoia%20%7C%20Sonoma-007AFF?style=flat-square&logo=apple&logoColor=white)](https://github.com/infoprojectstone/compressor)
  [![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
  [![Architecture](https://img.shields.io/badge/Arch-Apple%20Silicon-000000?style=flat-square&logo=apple)](https://github.com/infoprojectstone/compressor)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
  [![Ko-fi](https://img.shields.io/badge/Ko--fi-Apoyar-FF5E5B?style=flat-square&logo=kofi&logoColor=white)](https://ko-fi.com/infofprojectstone)
  [![Website](https://img.shields.io/badge/Web-GitHub%20Pages-2563EB?style=flat-square&logo=githubpages&logoColor=white)](https://infoprojectstone.github.io/compressor/)

  <br />

  <a href="https://github.com/infoprojectstone/compressor/releases">
    <img src="https://img.shields.io/badge/Descargar%20Instalador-.DMG-2563eb?style=for-the-badge&logo=apple&logoColor=white" alt="Descargar DMG" />
  </a>
  <a href="https://ko-fi.com/infofprojectstone">
    <img src="https://img.shields.io/badge/Invítame%20a%20un%20café-Ko--fi-ff5e5b?style=for-the-badge&logo=kofi&logoColor=white" alt="Apoyar en Ko-fi" />
  </a>
  <a href="https://infoprojectstone.github.io/compressor/">
    <img src="https://img.shields.io/badge/Visitar%20Sitio%20Web-Página%20Oficial-10b981?style=for-the-badge&logo=safari&logoColor=white" alt="Sitio Web" />
  </a>

  <br /><br />

  <img src="docs/assets/app_screenshot.png" width="920" alt="Compressor en macOS" />

</div>

<br />

## ✨ Características Principales

* ⏱️ **Diseñado para Ahorrar Tiempo:** Sin colas de subida en la nube ni interfaces confusas. Arrastra archivos, elige el peso que necesitas y comprime en segundos.
* 🔒 **Local y Seguro:** Tus fotografías personales, vídeos confidenciales y documentos nunca tocan la nube ni servidores de terceros. Cero telemetría y sin requerir conexión a internet.
* ⚡ **Aceleración por GPU:** Codificación nativa de vídeo y procesamiento gráfico ultra-rápido mediante `AVFoundation`, `CoreGraphics` e `ImageIO`, optimizado para chips Apple Silicon.
* 🛡️ **Garantía Anti-Pérdida:** Los archivos originales nunca se sobrescriben. Y si una compresión no consigue reducir el peso del archivo, el sistema lo descarta automáticamente avisándote con el estado *"Sin mejora"*.
* 📁 **Integración con Finder:** Comprime archivos o carpetas enteras con un solo clic derecho desde el menú contextual de Finder sin necesidad de abrir la aplicación previamente.
* 🎯 **Doble Modo de Operación:**
  * **Modo Calidad:** Elige entre *Alta calidad*, *Equilibrado* o *Tamaño pequeño*.
  * **Modo Tamaño Objetivo:** Define el peso máximo exacto deseado en megabytes (MB) (ideal para correos, WhatsApp o plataformas con límites estrictos de subida).

---

## 🗂️ Los Tres Motores en Detalle

### 📸 1. Imágenes
* **Formatos soportados:** JPG, PNG, WebP, HEIC (fotos del iPhone) y HEIF.
* **Preservación inteligente:** Mantiene la transparencia alfa y perfiles de color originales.
* **Ahorro típico:** De un **-60% a un -95%** sin pérdida visual apreciable.

### 🎬 2. Vídeo
* **Formatos soportados:** MP4, MOV y M4V.
* **Tecnología:** Pipeline nativo con `AVAssetReader` + `AVAssetWriter` con control de bitrate adaptativo en dos pasadas y audio estéreo AAC de alta definición.
* **Resoluciones:** Auto (máx. 1080p), 720p, 540p o resolución original.
* **Ahorro típico:** De un **-50% a un -85%**.

### 📄 3. Documentos PDF (`SafePDFCompressor`)
* **Nuevo motor híbrido en dos niveles nativos:**
  * **Nivel 1 (Vectorial con `QuartzFilter`):** Optimiza y recompime las fotos e imágenes embebidas, **preservando toda la nitidez de tipografías, hipervínculos y texto seleccionable**.
  * **Nivel 2 (Rasterización Adaptativa Inteligente):** Diseñado específicamente para documentos escaneados (páginas que son imágenes puras). Calcula el presupuesto de bytes por página para garantizar que el archivo final sea siempre más ligero que el original.
* **Ahorro típico:** De un **-50% a un -95%**.

---

## 🖱️ Integración con Finder (Acción Rápida)

Puedes comprimir cualquier archivo o carpeta directamente desde Finder:

1. Abre **Ajustes** dentro de Compressor (`Cmd` + `,`).
2. Ve al apartado **Integración con Finder** y pulsa en **"Instalar Acción Rápida"**.
3. Haz clic derecho sobre cualquier imagen, vídeo o PDF en Finder y selecciona:
   * **Acciones rápidas > Comprimir con Compresor** (o desde el menú de Servicios).
   * La aplicación se abrirá instantáneamente, cambiará a la pestaña correcta y encolará los archivos seleccionados para procesarlos.

---

## 🚀 Instalación y Seguridad (Gatekeeper)

Al tratarse de una aplicación independiente de código abierto distribuida sin certificado de pago corporativo de Apple Developer:

1. Descarga [`Compressor-1.2.dmg`](https://github.com/infoprojectstone/compressor/releases) y ábrelo.
2. Arrastra **Compressor** a la carpeta **Aplicaciones**.
3. La primera vez que abras la app, si macOS muestra el aviso *"no se puede abrir porque Apple no puede comprobar si contiene software malicioso"*:
   * Haz **clic derecho** (o `Control` + clic) sobre Compressor en la carpeta Aplicaciones y pulsa en **Abrir**.
   * O bien ve a **Ajustes del Sistema > Privacidad y seguridad** y haz clic en **"Abrir igualmente"**.

---

## 🛠️ Compilación y Desarrollo

Requisitos: macOS 13.0 o superior, Xcode Command Line Tools (`xcode-select --install`).

* **Ejecutar la suite completa de pruebas:**
  ```bash
  zsh scripts/run-tests.sh
  ```

* **Compilar la aplicación en Release y generar el .ZIP:**
  ```bash
  zsh scripts/build-app.sh
  ```

* **Generar el instalador DMG:**
  ```bash
  zsh scripts/create-dmg.sh
  ```

---

## ☕ Apoya el Proyecto

Compressor es una herramienta independiente y gratuita. Si la aplicación te ha **ahorrado tiempo** o te ha sacado de un apuro con un archivo pesado, puedes apoyar su desarrollo y mantenimiento continuo invitándome a un café:

👉 **[Invítame a un café en Ko-fi (ko-fi.com/infofprojectstone)](https://ko-fi.com/infofprojectstone)**
