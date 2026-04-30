# Splynek

> **Versión española resumida.** Para la documentación completa, consulta [README.md](README.md) (en inglés).

Splynek es un gestor de descargas para macOS que combina todas las conexiones de red de tu Mac — Wi-Fi, Ethernet, conexión compartida del iPhone — para descargar archivos más rápido de lo que permite cualquier conexión aislada.

## Qué hace diferente a Splynek

- **Más rápido** — suma el ancho de banda de todas las redes conectadas simultáneamente. En pruebas, 1,8× a 3,5× más rápido que Safari sobre una única red.
- **Honesto** — cada descarga se verifica contra la suma de comprobación del autor. Nada se guarda en disco antes de confirmar la integridad.
- **Privado** — nada sale de tu Mac. Sin cuenta. Sin telemetría. Sin registros.
- **Soberano** — descubre de dónde vienen las apps de tu Mac y cuáles tienen alternativas europeas o de código abierto.

## Las pestañas principales

| Pestaña | Qué hace |
|---------|----------|
| **Descargas** | URL, suma de comprobación opcional, elige las redes a usar, descarga. |
| **Torrents** | Soporte nativo de BitTorrent v1+v2 (DHT, PEX, magnet, multiarchivo). |
| **En Vivo** | Visualiza en tiempo real el ancho de banda por red mientras descargas. |
| **Soberanía** | Analiza las apps instaladas y sugiere alternativas europeas / código abierto. Local; nada sale del dispositivo. |
| **Confianza** | Auditoría de registro público de tus apps — etiquetas de privacidad de App Store, multas regulatorias, CVE, filtraciones HIBP. Sin editorial. Cada afirmación cita la fuente. |
| **Agentes** | Servidor MCP — permite que Claude, ChatGPT u otros agentes de IA controlen Splynek. Desactivado por defecto. |
| **Cola** | Cola persistente de URLs para descargar más tarde. |
| **Flota** | Coordinación entre varios Mac en la misma red local. |
| **Historial** | Todo lo que has descargado. Buscable, indexado en Spotlight. |

## Cómo instalar

**Mac App Store** (en revisión para v1.0): https://apps.apple.com/app/splynek

**DMG directo** (gratuito, firmado con Developer ID, notarizado):
- [GitHub Releases](https://github.com/Splynek/splynek/releases) — descarga el `.dmg` más reciente

**Homebrew**:
```bash
brew tap Splynek/splynek
brew install --cask splynek
```

## Privacidad — el contrato

- Splynek **nunca** envía datos a nuestros servidores. No tenemos servidores.
- Splynek **nunca** abre el contenido de tus apps. Los análisis de Soberanía y Confianza leen solo la lista de paquetes instalados — lo mismo que hace Spotlight.
- Splynek **nunca** sube tu historial o lista de apps a la nube.
- El servidor web local (que usa Splynek para mostrar progreso o integrarse con extensiones del navegador) escucha solo en `127.0.0.1` por defecto.

## Idiomas soportados

Splynek está disponible en **inglés**, **portugués (Portugal)**, **español**, **francés**, **alemán** e **italiano**. Consulta [LOCALIZATION.md](LOCALIZATION.md) para el flujo de contribución (PRs con traducciones son bienvenidos).

## Contribuir

- El catálogo Soberanía (1100+ apps, alternativas europeas / OSS) se mantiene en [`Scripts/sovereignty-catalog.json`](Scripts/sovereignty-catalog.json) — consulta [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md).
- El catálogo Confianza (60 apps, con fuentes primarias) está en [`Scripts/trust-catalog.json`](Scripts/trust-catalog.json).
- Errores, sugerencias: [github.com/Splynek/splynek/issues](https://github.com/Splynek/splynek/issues).

## Licencia

[BSD 3-Clause](LICENSE).
