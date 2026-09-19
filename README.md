# Tecnomat · Control de Materiales

App de gestión de stock, montaje/proyectos y pedidos con escaneo de código de barras (lector USB/Bluetooth o cámara del móvil), pensada para funcionar como una única página web (`index.html`).

## Cómo está construida

El objetivo era tener una herramienta de almacén que no necesitara servidor propio, se pudiera alojar gratis (GitHub Pages) y funcionara bien tanto en ordenador como en el móvil de un operario. Eso llevó a la decisión de arquitectura principal: **una única página HTML autocontenida**, sin build, sin framework, sin `npm install` — todo el HTML, CSS y JavaScript viven en un solo archivo (`index.html`).

**Stack técnico:**
- **JavaScript vanilla**, sin framework.
- **CSS con variables personalizadas** para recolorear secciones enteras (Trabajo, Almacén, Pedido) cambiando solo unas pocas líneas.
- **SheetJS** para leer/escribir Excel y CSV directamente en el navegador.
- **pdf.js** para extraer texto de PDFs al crear órdenes desde archivo (análisis heurístico línea a línea).
- **JsBarcode** para generar e imprimir etiquetas de código de barras.
- **jsPDF** para juntar las páginas escaneadas de un documento en un único PDF.
- **Supabase (Postgres + Authentication + tiempo real)**, opcional, para guardado compartido en la nube con login — ver "Migrar a otro hosting o base de datos" si en algún momento se cambia de proveedor.
- **EmailJS**, opcional, para mandar avisos por correo sin backend propio.
- **`BarcodeDetector`** (API nativa del navegador) para escanear con la cámara del móvil.

**Modelo de datos:** el estado vive en un único objeto JavaScript. El catálogo de materiales usa un `id` interno único por referencia — el código de barras (`code`) **no tiene que ser único**, así que un mismo código puede tener varias referencias asociadas, y la app pregunta cuál es al escanear si hay más de una coincidencia.

**Guardado, en cadena de prioridad:** Supabase (si está configurado, con ajustes de stock a prueba de que dos dispositivos no se pisen un cambio, y tiempo real) → almacenamiento propio de la página → `localStorage` del navegador. La app nunca deja de guardar datos, solo cambia dónde.

**Decisiones de diseño relevantes:**
- Todos los datos dinámicos se escapan antes de pintarlos en HTML, porque pueden venir de un escáner o de un humano y contener caracteres que rompan la página.
- Al subir un archivo para crear una orden, la app enseña primero un resumen línea a línea y pide confirmación antes de tocar el stock.
- El histórico de movimientos y de firmas se archiva resumido en vez de borrarse sin más al superar un límite.
- Las funciones opcionales (cámara, Supabase, EmailJS, PDF) se degradan sin romper el resto de la app si no están disponibles o configuradas.

**Limitaciones conocidas:**
- Al ser una página estática, los avisos programados (stock bajo, bobinas por vencer) solo se comprueban cuando alguien tiene la app abierta — no hay tarea en segundo plano que se ejecute sola. El correo de pedido nuevo sí funciona siempre que se guarde una solicitud, esté quien esté conectado.
- La lectura de PDF es heurística (busca patrones de texto), no una lectura de tablas real.
- El pitido de aviso depende de que el navegador permita reproducir audio sin una interacción previa del usuario en esa pestaña — algunos navegadores (sobre todo Safari en iPhone) son más estrictos que otros. Si esto falla en algún dispositivo puntual, la notificación del sistema (si se le dio permiso) sigue llegando igual, ya que no depende de esta restricción.
- Las firmas de entrega, al ser una imagen, solo se guardan completas las 40 más recientes por orden/proyecto (para no hacer crecer demasiado esa fila); las más antiguas se archivan como resumen (quién, cuándo, cuántas líneas) sin la imagen.
- El logo de la empresa no sale como imagen en los Excel exportados — la librería gratuita usada para generarlos no lo permite, solo el texto "TECNOMAT · Control de materiales".

## 1. Publicarla en GitHub Pages

1. Entra en [github.com](https://github.com) y crea un repositorio nuevo (botón **New repository**).
2. Dentro del repositorio, pulsa **Add file → Upload files** y sube todos los archivos de esta carpeta (`index.html`, `sw.js`, `manifest.json`, `icon-192.png`, `icon-512.png`) a la raíz del repositorio, no dentro de ninguna subcarpeta.
3. Haz commit de los cambios (botón verde **Commit changes**).
4. Ve a **Settings → Pages** (menú lateral del repositorio).
5. En **Build and deployment → Source**, selecciona **Deploy from a branch**.
6. En **Branch**, elige `main` (o `master`) y la carpeta `/ (root)`. Guarda.
7. Espera 1-2 minutos. GitHub muestra una URL parecida a `https://tu-usuario.github.io/tu-repositorio/`.

**Al subir cambios más adelante:** sube siempre `index.html` **y** `sw.js` juntos, y sube en 1 el número de la primera línea de verdad de `sw.js`:
```js
const CACHE_NAME = 'tecnomat-materiales-v4'; // súbelo a v5, v6... cada vez que subas cambios
```
Si subes `index.html` nuevo pero te olvidas de tocar `sw.js`, el navegador no se entera de que hay nada distinto y el aviso de "hay una versión nueva" no salta.

## 2. Cómo se guardan los datos

- **Con Supabase configurado**: guardado compartido en la nube, con tiempo real entre dispositivos.
- **Sin Supabase configurado**: usa `localStorage`, la memoria propia del navegador — sigue guardándose todo solo, pero queda en ese navegador y dispositivo concretos, sin sincronizarse con otros.

**Recomendación:** usa el botón **"Descargar todo"** (dentro de Almacén) de vez en cuando para bajarte una copia de seguridad real en un archivo `.json`, y **"Restaurar"** si necesitas pasar esos datos a otro dispositivo o recuperarlos tras borrar el navegador.

## 3. Backend real (Supabase)

GitHub Pages solo sirve archivos estáticos — no puede ejecutar un servidor ni una base de datos. Por eso el `index.html` se conecta, si se quiere, a **Supabase** (base de datos Postgres gratuita, con tiempo real y login incluidos): la página sigue alojada 100% en GitHub Pages, pero los datos se guardan en esa base externa y todos los dispositivos comparten el mismo stock en tiempo real. Es también la base que permite que **otra app conectada al mismo proyecto** dé de alta órdenes de trabajo directamente, sin pasar por Tecnomat.

### Configuración desde cero

1. Ve a [supabase.com](https://supabase.com) y crea una cuenta (gratis).
2. **New project** → nombre, contraseña de la base de datos (guárdala), región más cercana. Espera 1-2 minutos.
3. Menú lateral → **SQL Editor** → **New query** → pega el contenido de `supabase_setup.sql` (incluido en esta carpeta) → **Run**. Esto crea las tablas, la función de ajuste de stock, y activa el tiempo real.
4. Menú lateral → **Project Settings** (⚙) → **API** → copia la **Project URL** y la clave **anon public**.
5. En `index.html`, dentro del adaptador de backend cerca del principio del `<script>`, sustituye `TU_SUPABASE_URL` y `TU_SUPABASE_ANON_KEY` por esos dos valores.
6. **Authentication → Users → Add user** para crear las cuentas de acceso (por ejemplo, `taller@tecnomat.es` y la de Almacén).

### Nota de seguridad

El SQL de configuración ya deja las tablas cerradas a cualquiera que no haya iniciado sesión (Row Level Security activada, con una política que exige `auth.role() = 'authenticated'`). Con eso basta para que nadie sin cuenta pueda leer ni escribir nada, aunque conozca la URL y la clave pública del proyecto — la clave `anon` está pensada para ir en el código del cliente, no es un secreto por sí sola.

**Restricción real para Taller** (la de la interfaz, ver sección 5, es solo visual) — para impedir de verdad que esa cuenta escriba en el catálogo o los movimientos, se puede añadir una política más estricta sobre esas dos claves en `tecnomat_kv`, comprobando el email de quien ha iniciado sesión (`auth.jwt() ->> 'email'`) en vez de solo si hay sesión.

### La otra app conectada al mismo proyecto

Si otra app también inserta filas en `ordenes_trabajo` (y sus materiales en `orden_materiales`), Tecnomat las detecta solo, en tiempo real, y crea la orden/proyecto correspondiente — sin tener que darla de alta a mano. Ver la sección "Trabajo" más abajo para el detalle de qué pasa exactamente al recibir una.

La tabla `materiales_rapidos` (para la "Lista rápida" de Trabajo, ver esa sección) no la llena ninguna app — se edita a mano directamente en Supabase (Table Editor → `materiales_rapidos` → Insert row), con `codigo` (opcional, para que enlace con un artículo real del stock) y `nombre`.

Si no se rellenan `supabaseUrl`/`supabaseAnonKey` (se dejan con los valores de ejemplo), la app sigue funcionando con guardado local, sin romper nada.

## 4. Avisos y notificaciones

**Correo (EmailJS, gratis):**
1. Cuenta gratuita en [emailjs.com](https://www.emailjs.com).
2. **Email Services → Add New Service**, conectar una cuenta de correo. Apuntar el **Service ID**.
3. **Email Templates → Create New Template**, con las variables `{{subject}}`, `{{message}}`, `{{to_email}}` en el cuerpo. Apuntar el **Template ID**.
4. **Account → General** → copiar la **Public Key**.
5. En `index.html`, bloque `emailjsConfig` (cerca de las claves de Supabase), sustituir las tres claves.
6. Dentro de la app, Almacén → panel "Avisos", poner el email de destino y guardar.

Sin `emailjsConfig` configurado, los avisos siguen apareciendo como banner dentro de la app, solo que sin correo.

**Qué avisa la app, y por qué canal:**
- **Stock bajo / bobinas por vencer**: banner al entrar en cualquier sección, y un correo diario (a partir de la hora configurada en Avisos) con el resumen. Un resumen semanal aparte incluye lo que más se ha movido.
- **Pedido nuevo desde Trabajo o Pedido**: al guardar una Hoja de pedido, o cuando Taller envía algo por el chat, Almacén recibe tres cosas — correo, un banner dentro de la app (pulsarlo lleva directo a esa orden), y un pitido + notificación del sistema en cualquier dispositivo con la app abierta.
- **Sin conexión**: banner en rojo si se corta el internet a media faena, avisando de que los cambios se siguen guardando en el dispositivo pero no se sincronizan hasta que vuelva. Avisa también al recuperarse.
- **Sonido al escanear**: pitido corto al confirmar un escaneo con éxito (distinto del de "pedido nuevo"), desactivable en Almacén → Avisos.

Todo lo anterior (banner, sonido, notificación del sistema) solo funciona con la app abierta en ese momento, aunque sea en segundo plano si está instalada — para que funcione con la app completamente cerrada haría falta notificaciones push de verdad, una pieza bastante más grande de montar. El correo es el único de los avisos que llega siempre, esté la app abierta o no.

## 5. Roles: Almacén y Taller

Quien entra con la cuenta **`taller@tecnomat.es`** no ve la pestaña de Almacén, ni "Finalizar"/"Eliminar" en una orden, ni el botón "Asociar" en el chat — solo puede trabajar desde Trabajo y Pedido. Cualquier otra cuenta ve todo.

**Esto es una restricción de interfaz**, no de seguridad real — oculta botones y redirige, pero no impide técnicamente que alguien con conocimientos edite datos saltándose la pantalla. La restricción real (a nivel de base de datos) se configura con Row Level Security en Supabase, ver sección 3.

## 6. Trabajo (Montaje/Venta y Proyecto) y su chat

Montaje/Venta y Proyecto viven bajo una sola pestaña, **Trabajo** — al crear una orden se elige el tipo en un desplegable. Por dentro cada uno se sigue guardando por separado, solo cambia cómo se llega hasta ahí desde la pantalla.

**El chat es la forma principal de pedir material** en una orden o proyecto, justo debajo del selector (que vive integrado ahí mismo, con "Finalizar"/"Eliminar" escondidos detrás de "Más opciones" para no saturar la pantalla, y "+ Nueva orden/proyecto" para crear otra):
- Cada escaneo aparece como mensaje en el hilo, en orden, junto con avisos como "Hoja guardada", "Recogida confirmada y firmada" o "Asociado a...".
- Se puede **escribir directamente** (no solo escanear) para pedir algo aunque no se sepa la referencia — queda como línea "sin referencia todavía".
- **Solo Almacén** ve el botón **"Asociar"** en esas líneas, para enlazarlas con una referencia real (con el lector físico USB/Bluetooth, la cámara del móvil, o escribiéndolo a mano — un campo de texto normal acepta las tres formas) — y si esa referencia no existe todavía, se puede dar de alta ahí mismo, con 0 unidades.
- El chat tiene un alto fijo con su propio scroll, y se desplaza solo hasta el último mensaje.
- La tabla de siempre (**Hoja de pedido**, y **Servido**/**Devuelto** para Almacén) sigue existiendo en su propia pestaña, para imprimir o repasar de un vistazo — el chat no la sustituye, conviven las dos.
- El panel lateral también empieza compacto — solo "Resumen" a la vista, el resto (exportar, crear desde archivo, buscar en stock, histórico, entregas firmadas) detrás de "Más opciones".
- **Lista rápida**: justo encima de la caja de escribir del chat, si hay materiales frecuentes configurados, aparece una lista pequeña con casilla y cantidad para cada uno — misma lista para todas las órdenes y proyectos. Al marcar los que hagan falta y pulsar "Añadir seleccionados", se añaden de golpe a la solicitud pendiente (con su referencia real si el código coincide con algo del stock, o como línea "sin referencia todavía" si no), y queda anotado en el chat. Esta lista se mantiene aparte, directamente en Supabase (tabla `materiales_rapidos`), y se actualiza sola en cualquier dispositivo en cuanto cambia.

**¿Quién pide el material?** No es un campo fijo en pantalla — al crear una orden, una ventana lo pregunta y obliga a rellenarlo. Cada tanda de material (cada vez que se firma una entrega, la orden queda lista para una tanda nueva) puede ser pedida por alguien distinto: si hace falta, se vuelve a preguntar con una ventana en el momento de escanear o escribir, sin bloquear ni esconder el chat mientras tanto.

**Flujo de entrega, con firma:**
1. Se escanea o se pide por chat el material necesario — no descuenta stock todavía, queda en la "Solicitud pendiente de recoger".
2. Al pulsar **"Preparar recogida y firmar"**, la app comprueba que hay stock real de cada línea.
3. La persona que recoge firma con el dedo o el ratón.
4. Al **"Confirmar entrega"** es cuando se descuenta el stock de verdad, y las líneas pasan a "Servido" — hasta ese momento no se ha tocado nada, por si se cancela a mitad de camino.
5. Queda un registro (quién pidió, quién recogió y firmó, qué materiales) en "Entregas firmadas", exportable a Excel.

Cada línea de la Hoja de pedido tiene además dos campos editables: **"Escandallo/Pedido"** (si ese material se pasó a un escandallo de costes o a un pedido a proveedor) y su **número identificativo** — editables tanto en líneas pendientes como en las **ya servidas**, ya que normalmente se sabe después de entregar el material, no antes. Al elegir el tipo en una línea, si ya hay otra línea de la misma hoja con ese mismo tipo y número puesto, se copia solo. Con la casilla por línea se pueden marcar varias a la vez (pendientes o servidas, mezcladas si hace falta), pidiendo un único número para todas las seleccionadas. **"Plano"** es un dato de toda la orden, no por línea — se edita en la cabecera de la Hoja de pedido, junto a la OT.

Una orden o proyecto **no se cierra sola** al entregar material — sigue activa y se puede seguir añadiendo hasta que alguien de Almacén pulse "Finalizar" a propósito.

**Órdenes creadas por otra app**: si otra app conectada al mismo proyecto de Supabase inserta una fila en `ordenes_trabajo` (con sus materiales en `orden_materiales`), Tecnomat la detecta en tiempo real y hace todo esto sola, sin intervención:
- Crea la orden o proyecto con el nombre, tipo e Interno/Externo que traiga.
- Busca cada material en el stock — si lo encuentra, lo añade a la solicitud pendiente con su referencia real; si no, lo deja como línea "sin referencia todavía" (con el botón "Asociar" para Almacén, igual que el resto).
- Dice quién lo pidió, y lo deja anotado en el chat de esa orden.
- Avisa a Almacén igual que con cualquier pedido nuevo (correo, banner, sonido).

Si Tecnomat todavía no está configurado con Supabase (ver sección 3), esta parte simplemente no ocurre y las órdenes se siguen creando a mano como siempre.

## 7. Pedido

Sirve para pedir material que falta en el almacén (por ejemplo, para reponer stock desde un proveedor) — no lleva firma, es un listado que se manda por correo. Tiene el mismo chat que Trabajo (con su pestaña "Chat" y "Lista"), pero aquí **se pregunta quién hace el pedido en cada escaneo o mensaje**, no solo una vez — pensado para un dispositivo que se comparte entre varias personas. Cada línea del chat muestra quién pidió esa unidad en concreto.

## 8. Mantenimiento

Pestaña para llevar el mantenimiento de los vehículos de la empresa (furgonetas, coches de reparto...), independiente del resto de secciones — no descuenta stock ni tiene escáner, es solo un seguimiento de fechas y kilometraje.

- Se pueden dar de alta **varios vehículos** (matrícula, marca, modelo, año, kilómetros actuales), cambiando entre ellos con un desplegable, con botón para editarlos o eliminarlos. Se identifican por matrícula, como es natural en una flota de empresa.
- **Mecánico habitual**: nombre y contacto (teléfono o email) por vehículo, visibles en el panel lateral.
- **Fotos**: se pueden añadir fotos (con la cámara del móvil o desde archivo) enlazadas a cada vehículo, con una pequeña galería y opción de eliminarlas. Se comprimen automáticamente antes de guardarlas.
- Cada tarea de mantenimiento (cambio de aceite, ITV, correa de distribución, frenos...) tiene un intervalo en **kilómetros y/o en meses** — avisa con lo que llegue antes. Hay una lista de tareas habituales que rellena los intervalos típicos al elegirlas, editables después.
- Cada tarea se ve en verde (al día), naranja (pronto) o rojo (atrasada), con un resumen arriba del recuento de cada estado.
- **"Hecho"** actualiza el kilometraje y la fecha de esa tarea con un par de datos, y recalcula sola la próxima vez.
- **Los avisos de mantenimiento pendiente entran en el mismo sistema de avisos que ya usa el resto de la app**: aparecen en el banner de arriba (junto a los de stock bajo, si los hay) y en el correo diario, sin tener que entrar a mirar la pestaña a propósito.
- No tiene buscador de stock ni escáner — esta sección no descuenta ni consulta material.
- Los datos se guardan igual que el resto de la app — en la nube si Supabase está configurado, compartidos entre todos los dispositivos con la sesión iniciada.

## 9. Almacén

- **Panel lateral compacto**: por defecto solo se ven "Resumen" y "Últimos movimientos" — el resto (Exportar/Importar, Sobrescribir todo el stock, Copia de seguridad, Avisos, Ubicaciones, Histórico general, Actividad) se esconde detrás de un botón "Más opciones", para no abrumar con paneles que se usan poco.
- **Materiales sincronizados desde A3**: si otra app conectada al mismo proyecto de Supabase sincroniza el catálogo de artículos de A3 (código, descripción, precio de venta, stock según A3), Tecnomat los recibe solo, en tiempo real. Si el código ya existe en el stock, se actualiza la descripción sin tocar la cantidad real (esa la sigue llevando Tecnomat, sumando y restando por escaneo); si es un código nuevo, se da de alta con 0 unidades, a la espera de que entre stock de verdad. El número de stock que trae A3 se guarda aparte, solo de referencia — nunca sustituye a la cantidad real de Tecnomat.
- **Editar**: un único botón agrupa artículo, referencia, ubicación, categoría, coste y características en un solo formulario. Dentro de ese mismo formulario están también **Etiqueta**, **+ Otra referencia** y **Eliminar** — así cada fila de la lista solo muestra dos botones ("Editar" y "Cambiar cantidad"), en vez de cinco, que en una lista de decenas de artículos se nota mucho.
- **Filtros**: por categoría, solo stock bajo (0) o solo sin ubicar, combinables con la búsqueda de texto.
- **Ubicaciones**: panel para mantener una lista (añadir/quitar) que autocompleta al escribir la ubicación de un material — sigue siendo texto libre, esto solo evita erratas.
- **Valorización**: columna "Coste" reconocida al importar un Excel, o rellenable a mano por artículo. El resumen de Almacén muestra el valor total del inventario.
- **Trazabilidad**: cada movimiento, eliminación y entrega firmada guarda el email de quien lo hizo (si hay login).
- **Entrada/Salida al escanear**: interruptor junto al escáner para elegir si el escaneo suma o resta stock. El escáner va siempre justo debajo del buscador en Almacén, antes de la lista de stock — con inventarios largos, no queda empujado fuera de la vista.
- **Rendimiento con inventarios grandes**: la lista solo pinta 80 artículos a la vez, con "Cargar más" para ver el resto.
- **Colores pensados para daltonismo**: ningún dato depende solo del color (siempre hay texto o número también). Pedido usa magenta y Stock bajo/OK usan rosa/verde azulado en vez de rojo/verde puros, para distinguirse bien bajo daltonismo rojo-verde.
- **Tour inicial y botón "Ayuda"**: repaso corto de la app que aparece solo la primera vez, y se puede volver a abrir cuando se quiera.

## 10. Crear una orden/proyecto subiendo un archivo (Excel, CSV o PDF)

Dentro de Trabajo, con una orden seleccionada, hay un botón para subir un archivo. Busca cada línea en el stock (por código o referencia) y la añade a la solicitud pendiente — no descuenta stock directamente, eso solo pasa al preparar la recogida y firmar.

- **Excel/CSV**: fiable, reconoce columnas tipo Código, Referencia/Descripción y Cantidad.
- **PDF**: "mejor esfuerzo" — sin columnas reales, la app busca en cada línea de texto algo con forma de "referencia ... cantidad al final". Con listados sencillos funciona bien; con PDFs de diseño complicado puede no acertar — en ese caso, mejor subir el Excel/CSV original.

Si una línea no coincide con nada del stock, se da de alta automáticamente como referencia "plantilla" (sin stock real) para completarla más tarde. Antes de aplicar el archivo, la app enseña un resumen línea a línea y pide confirmar.

## 11. Escanear un documento y guardarlo enlazado a su orden

Dentro de Trabajo, cada orden/proyecto tiene su propio panel de "Documentos escaneados" — útil para digitalizar un listado de material en papel, un albarán, o cualquier papel que llegue y haya que guardar junto a esa orden en concreto.

- **"Escanear documento"** abre la cámara del móvil. Se puede capturar **varias páginas seguidas** (cada una queda como una miniatura, y se puede tocar una para quitarla antes de terminar).
- Al pulsar **"Convertir a PDF"**, todas las páginas capturadas se juntan en un único PDF, que queda guardado y enlazado a esa orden/proyecto — no a ninguna otra.
- Desde el propio panel se puede **"Ver"** el PDF en una pestaña nueva, o **"Eliminar"** el documento.
- Se guardan hasta 20 documentos por orden/proyecto; a partir de ahí, los más antiguos se van sustituyendo.

## 12. Instalar la app en el móvil (PWA)

Gracias a `manifest.json`, `sw.js` y los iconos (súbelos todos junto al `index.html`):
- **Android (Chrome)**: aviso de "Añadir a pantalla de inicio", o menú ⋮ → "Instalar app".
- **iPhone (Safari)**: botón compartir → "Añadir a pantalla de inicio".

Una vez instalada, abre en pantalla completa y guarda una copia básica en caché para no quedarse en blanco si se corta la conexión un momento.

Cuando se suben cambios nuevos, aparece un banner — *"Hay una versión nueva disponible"* — con un botón para actualizar. Hasta que no se pulse, sigue con la versión que ya tenía cargada.

## Migrar a otro hosting o base de datos

Todo lo que depende de Supabase vive dentro de un único objeto, `backend`, cerca del principio del `<script>` — el resto de la app nunca menciona Supabase directamente fuera de ese bloque, solo llama a `backend.get/set/delete/watch` y a `backend.auth.*`.

- **El hosting** ya es independiente del backend — es un único archivo HTML, funciona en GitHub Pages, Netlify, Vercel, un servidor propio, o cualquier sitio que sirva archivos estáticos, sin cambiar nada.
- **La base de datos** es lo que está concentrado en el objeto `backend`. Para migrar de verdad, hay que escribir un objeto nuevo con esta misma forma y sustituir el `backend = {...}` actual:

```js
backend = {
  async get(key){ /* devuelve el valor guardado bajo esa clave, o null */ },
  async set(key, value){ /* guarda value bajo esa clave */ },
  async delete(key){ /* borra esa clave */ },
  watch(key, applyFn){ /* opcional: si el backend nuevo tiene tiempo real, se
    suscribe y llama a applyFn(valor) cada vez que cambia; si no lo tiene, se
    puede dejar sin hacer nada y la app sigue funcionando sin tiempo real */ },
  async adjustStockAtomic(item, delta){ /* opcional: ajuste de stock a prueba de
    que dos dispositivos escriban a la vez; si el backend nuevo no tiene
    transacciones, aquí se puede hacer un "leer, sumar, guardar" normal */ },
  auth: {
    signIn(email, pass){ /* inicia sesión, devuelve una promesa */ },
    signOut(){ /* cierra sesión */ },
    onChange(cb){ /* llama a cb(usuario) cuando cambia la sesión, o cb(null) si no hay */ },
    currentUserEmail(){ /* devuelve el email de quien ha iniciado sesión, o '' */ }
  }
};
```

Si el proyecto nuevo no necesita usuarios con contraseña, `backend.auth` se puede simplificar mucho — lo único que usa el resto de la app es saber el email de quien está dentro y si puede cerrar sesión.

Si se quiere conservar la detección automática de órdenes de trabajo creadas por otra app (ver sección 3), el backend nuevo necesita además:
```js
  watchOrdenesTrabajo(applyFn){ /* se suscribe a las órdenes nuevas y llama a
    applyFn(orden) por cada una; sin esto, las órdenes hay que seguir creándolas
    a mano dentro de Tecnomat, el resto de la app sigue funcionando igual */ },
  async getMaterialesDeOrden(ordenId){ /* devuelve la lista de materiales de esa
    orden, para poder rellenar la solicitud pendiente al recibirla */ }
```

Todo lo demás — catálogo, movimientos, chat, órdenes, Pedido, Hoja de pedido, diseño, avisos — llama siempre a `safeGet`/`safeSet`/`safeDelete`/`watchKey`/`getUserRole`/`currentUserEmail`, que reparten el trabajo entre `backend` y los otros dos niveles de reserva. Cambiar de base de datos no debería tocar ni una línea fuera de este bloque.
