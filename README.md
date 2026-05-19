# 🚀 WinOS Flash – Windows ISO Optimizer

[![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

**WinOS Flash** es una herramienta avanzada para modificar imágenes ISO de Windows (10 / 11).  
Elimina bloatware, desactiva telemetría, integra drivers, omite requisitos de hardware (TPM / Secure Boot) y aplica optimizaciones inteligentes con reglas dinámicas.  
Ideal para crear una instalación limpia, rápida y personalizada de Windows.

> ⚠️ **Advertencia**: Este script modifica archivos del sistema. Úsalo bajo tu propia responsabilidad. Siempre respalda tus datos originales.

---

## ✨ Características principales

| Categoría | Funcionalidad |
|-----------|----------------|
| 🧹 **Limpieza inteligente** | Elimina paquetes AppX, capacidades y componentes de Windows de forma segura mediante reglas basadas en build, edición y preferencias del usuario. |
| 🧠 **Eliminación selectiva** | OneDrive, Microsoft Edge, componentes de IA (Copilot, Recall), Xbox, YourPhone, Skype, Teams, aplicaciones de terceros. |
| 🔧 **Ajustes del Registro** | Deshabilita telemetría, GameDVR, Meet Now, anuncios, contenido sugerido, cifrado BitLocker, mejora la privacidad. |
| 💾 **Integración de drivers** | Añade drivers desde una carpeta local (ej. Intel RST/VMD) tanto en `install.wim` como en `boot.wim`. |
| 🛡️ **Bypass de requisitos** | Omite comprobaciones de TPM, Secure Boot, RAM, CPU y almacenamiento para hardware antiguo. |
| 📂 **Carpetas de usuario** | Restaura los clásicos iconos de "Escritorio", "Documentos", "Descargas" en el explorador (Windows 11). |
| ⚡ **Optimización de imagen** | Exporta WIM a máxima compresión o convierte a ESD (Recovery) para ahorrar espacio. |
| 🔁 **Creación de ISO** | Utiliza `oscdimg` (descarga automática) o método COM nativo para generar el ISO final. |
| 📝 **Registro detallado** | Guarda un log completo de todas las operaciones y comandos ejecutados. |
| 🎮 **Modo interactivo / silencioso** | Parámetros para automatización total (`-noPrompt`) o asistente paso a paso. |

---

## 📋 Requisitos previos

- **Sistema operativo**: Windows 10 / 11 (build 17000+ recomendado).  
- **Privilegios**: Administrador (el script se re-lanza automáticamente).  
- **Disco duro**: ~30 GB libres para trabajar con la imagen ISO.  
- **Conexión a Internet** (solo para descargar `oscdimg.exe` si no está presente).  
- **PowerShell 5.1** o superior (incluido por defecto en Windows).

---

## 📥 Comando de lanzamiento

### Rama Estable (Recomendada)

Abre **PowerShell como Administrador** y ejecuta:

```powershell
irm "https://raw.githubusercontent.com/ARCTTeam/WinOS-ISO-Debloater/main/isoLimpiadorScript.ps1" | iex
