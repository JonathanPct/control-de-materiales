# Cómo se construyó esta aplicación

Este documento explica las decisiones técnicas detrás de la app de Control de Materiales de Tecnomat: por qué está hecha así, qué problemas resuelve cada parte y cómo ha ido evolucionando.

## Planteamiento inicial

El objetivo era tener una herramienta de almacén (escaneo de códigos de barras, control de stock, órdenes de montaje, proyectos) que:

- No necesitara servidor propio ni mantenimiento de infraestructura.
- Se pudiera alojar gratis (GitHub Pages).
- Funcionara bien tanto en un ordenador de oficina como en el móvil de un operario en el almacén.
- No dependiera de instalar nada: abrir un enlace y listo.

Esas cuatro condiciones llevaron a la decisión de arquitectura más importante: **una única página HTML autocontenida**, sin build, sin framework, sin `npm install`. Todo el HTML, el CSS y el JavaScript viven en un solo archivo (`index.html`), lo que simplifica muchísimo el despliegue: subir un archivo a un repositorio y ya está publicado.

## Stack técnico

- **JavaScript vanilla**, sin framework (React, Vue, etc.). Para el tamaño y complejidad de esta app, un framework habría añadido una capa de build innecesaria sin aportar beneficios reales.
- **CSS con variables personalizadas** (`--accent`, `--bg-base`, etc.), lo que permite recolorear secciones enteras cambiando solo unas pocas líneas — así cada sección (Montaje/Venta, Almacén, Proyecto, Pedido) tiene su propio color de acento sin duplicar reglas de estilo.
- **SheetJS (xlsx.js)** para leer y escribir archivos Excel/CSV directamente en el navegador, sin pasar por ningún servidor.
- **pdf.js** para la lectura de PDFs al crear órdenes desde archivo (extracción de texto, con un análisis heurístico línea a línea para sacar referencia + cantidad).
- **Firebase (Firestore + Authentication)**, opcional: cuando está configurado, sustituye el guardado local por una base de datos en la nube, permitiendo que varios dispositivos compartan el mismo stock en tiempo real, con login por usuario/contraseña.
- **EmailJS**, opcional: permite enviar avisos por correo (stock bajo, bobinas por vencer, resúmenes) directamente desde el navegador, sin necesidad de un backend de envío de correos.
- **API nativa `BarcodeDetector`** del navegador para el escaneo de códigos con la cámara del móvil, con detección de compatibilidad y aviso claro cuando el navegador no la soporta.

## Modelo de datos y almacenamiento

El estado de la aplicación vive en un único objeto JavaScript (`state`) con las siguientes piezas principales:

- `catalog`: el stock — cada material tiene un `id` único, un `code` (código de barras) y una `desc` (referencia). El `code` **no es único**: un mismo código de barras puede tener varias referencias distintas asociadas (por ejemplo, cuando una etiqueta se reutiliza para materiales diferentes), y el sistema pide elegir cuál es al escanear si hay ambigüedad.
- `groups`: las órdenes de montaje y los proyectos, cada uno con su propio listado de material servido/devuelto.
- `movements`: el histórico de entradas, salidas y eliminaciones, usado tanto para el panel de actividad como para las exportaciones.
- `bobinas`, `pedidoItems`, `settings`, `alerts`: registros auxiliares (bobinas con fecha de devolución, pedidos pendientes de enviar, configuración de avisos).

Para el guardado, la app usa una **cadena de prioridad** en vez de depender de una única tecnología:

1. **Firestore** (si se ha configurado Firebase) — guardado compartido en la nube, con transacciones para evitar que dos dispositivos se pisen un cambio de stock a la vez, y listeners en tiempo real para que los cambios de otros se vean sin recargar.
2. **`localStorage`** del navegador, como alternativa automática si no hay Firebase configurado — así la app nunca deja de guardar datos, simplemente lo hace de forma local en vez de compartida.

Esta doble vía significa que la aplicación funciona igual de bien "de fábrica" (sin ninguna configuración) que con la nube activada — solo cambia dónde se guardan los datos, no cómo se usa la app.

## Decisiones de diseño relevantes

- **Escapado de HTML en todos los datos dinámicos** (`esc()`): los códigos de barras y las referencias los escribe un humano o los lee un escáner, así que pueden contener comillas u otros caracteres que rompan el HTML si se insertan sin escapar. Se resolvió con una función de escapado aplicada de forma sistemática en cada punto donde se pintan datos del usuario.
- **Confirmación antes de aplicar cambios masivos**: al subir un archivo (Excel/CSV/PDF) para crear una orden, la app primero analiza el archivo y muestra un resumen de lo que va a pasar línea a línea, y solo actúa tras confirmación explícita — para evitar que un archivo mal leído (sobre todo un PDF con maquetación compleja) descuadre el stock sin que nadie se dé cuenta.
- **Histórico con archivado, no con borrado**: en vez de eliminar sin más los movimientos antiguos al superar un límite, se resumen por mes (totales de entradas/salidas) y se guardan aparte, conservando el dato agregado aunque no cada línea individual.
- **Progressive enhancement en las funciones opcionales**: si no hay cámara compatible, si Firebase no está configurado, si EmailJS no tiene claves puestas o si pdf.js no carga, la aplicación no se rompe — simplemente esa función concreta queda desactivada con un aviso claro, y el resto sigue funcionando con normalidad.

## Evolución de funcionalidades

El desarrollo fue incremental, añadiendo capas sobre una base sencilla de escaneo y stock:

1. Escaneo de código de barras, listado de stock y control de entradas/salidas.
2. Separación en secciones: Almacén (stock), Montaje/Venta (órdenes), Proyecto y Pedido de materiales.
3. Registro de bobinas con fecha de devolución y avisos automáticos de stock bajo / vencimientos próximos.
4. Integración con Firebase (guardado compartido, login) y EmailJS (avisos por correo).
5. Soporte para que un mismo código de barras tenga varias referencias asociadas, con selector al escanear.
6. Creación de órdenes a partir de archivos Excel/CSV/PDF, con vista previa antes de confirmar.
7. Rediseño visual con identidad de marca (paleta de colores, logotipo).
8. Mejoras de fiabilidad: transacciones al ajustar stock, sincronización en tiempo real, deshacer acciones recientes, panel de actividad, resumen semanal por correo, selección múltiple en el listado de stock, y archivado del histórico de movimientos.
9. Conversión en aplicación instalable (PWA) mediante manifest y service worker, para poder añadirla a la pantalla de inicio del móvil.

## Limitaciones conocidas

- Al ser una página estática sin servidor propio, los avisos programados (diario/semanal) solo se comprueban cuando alguien tiene la aplicación abierta — no hay ninguna tarea que se ejecute "sola" en segundo plano si nadie ha abierto la página.
- La lectura de PDF es heurística (busca patrones de texto), no una lectura de tablas real — funciona bien con listados sencillos, pero puede fallar con documentos muy maquetados.
- Sin Firebase configurado, los datos se guardan solo en el navegador de cada dispositivo, sin compartirse automáticamente entre ellos.
