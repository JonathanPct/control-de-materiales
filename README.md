# Tecnomat · Control de Materiales

App de gestión de stock, montaje y proyectos con escaneo de código de barras (lector USB/Bluetooth o cámara del móvil), pensada para funcionar como una única página web (`index.html`).

## Cómo se construyó esta aplicación

El objetivo era tener una herramienta de almacén que no necesitara servidor propio, se pudiera alojar gratis (GitHub Pages) y funcionara bien tanto en ordenador como en el móvil de un operario. Eso llevó a la decisión de arquitectura principal: **una única página HTML autocontenida**, sin build, sin framework, sin `npm install` — todo el HTML, CSS y JavaScript viven en un solo archivo (`index.html`), lo que simplifica el despliegue a "subir un archivo y ya está publicado".

**Stack técnico:**
- **JavaScript vanilla**, sin framework — para el tamaño de esta app, un framework habría añadido una capa de build innecesaria.
- **CSS con variables personalizadas** para poder recolorear secciones enteras (Montaje/Venta, Almacén, Proyecto, Pedido) cambiando solo unas pocas líneas.
- **SheetJS** para leer/escribir Excel y CSV directamente en el navegador.
- **pdf.js** para extraer texto de PDFs al crear órdenes desde archivo (con un análisis heurístico línea a línea).
- **Firebase (Firestore + Authentication)**, opcional, para guardado compartido en la nube con login.
- **EmailJS**, opcional, para mandar avisos por correo sin backend propio.
- **`BarcodeDetector`** (API nativa del navegador) para escanear con la cámara del móvil.

**Modelo de datos:** el estado vive en un único objeto JavaScript. El catálogo de materiales usa un `id` interno único por referencia — el código de barras (`code`) **no tiene que ser único**, así que un mismo código puede tener varias referencias asociadas, y la app pregunta cuál es al escanear si hay más de una coincidencia. El guardado sigue una cadena de prioridad: **Firestore** (si está configurado, con transacciones para evitar que dos dispositivos se pisen un cambio, y tiempo real) → **`localStorage`** del navegador como alternativa automática si no hay Firebase — así la app nunca deja de guardar datos, solo cambia dónde.

**Decisiones de diseño relevantes:**
- Todos los datos dinámicos (códigos, referencias) se escapan antes de pintarlos en HTML, porque pueden venir de un escáner o de un humano y contener caracteres que rompan la página.
- Al subir un archivo para crear una orden, la app muestra primero un resumen de lo que va a pasar línea a línea y pide confirmación, antes de tocar el stock — para evitar que un archivo mal leído (sobre todo un PDF complicado) descuadre algo sin que nadie se dé cuenta.
- El histórico de movimientos, en vez de borrarse al superar un límite, se archiva resumido por mes.
- Las funciones opcionales (cámara, Firebase, EmailJS, PDF) se degradan sin romper el resto de la app si no están disponibles o configuradas.

**Evolución:** empezó como escaneo + stock básico, y fue creciendo por capas — secciones (Almacén/Montaje/Proyecto/Pedido), bobinas con avisos, Firebase + EmailJS, códigos con varias referencias, órdenes desde archivo con vista previa, rediseño con identidad de marca, y por último mejoras de fiabilidad (transacciones, tiempo real, deshacer, actividad, resumen semanal, selección múltiple) y conversión en app instalable (PWA).

**Limitaciones conocidas:** al ser una página estática, los avisos programados solo se comprueban cuando alguien tiene la app abierta (no hay tarea que se ejecute sola en segundo plano); la lectura de PDF es heurística, no una lectura de tablas real; y sin Firebase configurado, los datos no se comparten automáticamente entre dispositivos.

## 1. Publicarla en GitHub Pages

1. Entra en [github.com](https://github.com) y crea un repositorio nuevo (botón **New repository**). Puede llamarse, por ejemplo, `control-materiales`.
2. Dentro del repositorio, pulsa **Add file → Upload files** y sube el archivo `index.html` de esta carpeta (a la raíz del repositorio, no dentro de ninguna subcarpeta).
3. Haz commit de los cambios (botón verde **Commit changes**).
4. Ve a **Settings → Pages** (en el menú lateral del repositorio).
5. En **Build and deployment → Source**, selecciona **Deploy from a branch**.
6. En **Branch**, elige `main` (o `master`) y la carpeta `/ (root)`. Guarda.
7. Espera 1-2 minutos. GitHub te mostrará una URL parecida a:
   `https://tu-usuario.github.io/control-materiales/`
8. Entra en esa URL desde el móvil o el PC — ya puedes usar la app.

No hace falta instalar nada más: es un único archivo HTML autocontenido.

## 2. ¿Cómo se guardan los datos ahí?

La app usa un guardado con dos niveles, según lo que tengas configurado:

- **Con Firebase configurado** (ver sección 3): guardado compartido en la nube, con tiempo real entre dispositivos.
- **Sin Firebase configurado**: usa `localStorage`, la memoria propia del navegador. Sigue guardándose todo solo, sin que tengas que hacer nada — pero **queda guardado en ese navegador y dispositivo concretos**, no en un servidor compartido.

Esto significa que si entras desde el móvil del almacén y luego desde el ordenador de la oficina, cada uno tendrá su propio stock guardado por separado — no se sincronizan automáticamente entre sí.

**Recomendación:** usa el botón **"⬇ Descargar todo"** (dentro del modo Almacén) de vez en cuando para bajarte una copia de seguridad real en un archivo `.json`, y **"⬆ Restaurar"** si necesitas pasar esos datos a otro dispositivo o recuperarlos tras borrar el navegador.

## 3. ¿Se puede tener un backend real en GitHub?

**No directamente.** GitHub Pages solo sirve archivos estáticos (HTML, CSS, JavaScript) — no puede ejecutar un servidor, ni una base de datos, ni código en segundo plano.

Por eso el `index.html` puede conectarse, **si se quiere**, a **Firebase Firestore** (una base de datos gratuita de Google): la página sigue alojada 100% en GitHub Pages tal como está, pero en lugar de guardar los datos solo en el navegador, los guarda en esa base de datos externa — así todos los dispositivos (móviles y ordenadores) comparten el mismo stock en tiempo real.

### ✅ Esto ya está hecho en este proyecto

El `index.html` de esta carpeta ya tiene tu configuración real de Firebase metida (proyecto `almacenamiento-datos-40e38`), no hace falta repetir nada. Los pasos de abajo solo son referencia por si algún día necesitas:
- crear otra instancia de la app en un proyecto de Firebase distinto,
- o recordar de dónde salió esa configuración.

<details>
<summary>Ver pasos de configuración (referencia, ya completados)</summary>

1. Ve a [console.firebase.google.com](https://console.firebase.google.com) y entra con una cuenta de Google.
2. **Añadir proyecto** → ponle un nombre → puedes desactivar Google Analytics, no hace falta → **Crear proyecto**.
3. En el menú lateral, entra en **Compilación → Firestore Database** → **Crear base de datos**.
   - Elige la ubicación más cercana (p. ej. `eur3 (europe-west)`).
   - Selecciona **Modo de producción**.
4. Ve a **Configuración del proyecto** (⚙) → pestaña **General** → baja hasta "Tus apps" → pulsa el icono **Web `</>`**.
5. Ponle un apodo a la app → **Registrar app**. Firebase muestra un bloque `firebaseConfig`.
6. Ese bloque se pega en `index.html`, cerca del principio del `<script>`, sustituyendo los valores de ejemplo.

</details>

### ⚠️ Nota de seguridad importante

Por defecto, en modo de prueba, cualquiera que conozca tu configuración de Firebase podría leer o escribir en tu base de datos (no solo quien tenga la URL de tu página). Para una herramienta interna esto suele ser un riesgo aceptable si la URL no se hace pública, pero si quieres cerrarlo bien:

- En Firestore Database → pestaña **Reglas**, sustituye las reglas por algo como:
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /tecnomat_materiales/{doc} {
        allow read, write: if true; // ábrelo solo si confías en quién tiene el enlace
      }
    }
  }
  ```
- Si necesitas que solo la gente de tu empresa pueda entrar (con usuario y contraseña), la app ya incluye pantalla de login con **Firebase Authentication** — solo hace falta crear los usuarios (Authentication → Users) y ajustar las reglas para exigir `request.auth != null`.

Si no rellenas el `firebaseConfig` (lo dejas con los valores de ejemplo), la app simplemente sigue funcionando con guardado local en el navegador, como hasta ahora — no rompe nada.

## 4. Bobinas y avisos (stock bajo / fechas de devolución)

Dentro de Almacén hay ahora una sección para registrar bobinas (descripción, matrícula y fecha en la que hay que devolverlas). Cada vez que entras en cualquier apartado de la app, sale un aviso arriba si:
- alguna bobina está a punto de llegar a su fecha de devolución (el margen de días lo configuras tú en el panel "Avisos", dentro de Almacén), o
- algún material tiene menos unidades de las que consideras "stock bajo" (también configurable, por defecto 2).

Además, una vez al día (a partir de la hora que configures) la app intenta mandarte un correo con el resumen: si hay materiales con stock bajo, los lista junto con las bobinas que estén por vencer (todo en un solo correo); si no hay stock bajo pero sí bobinas por vencer, manda un correo solo con eso.

**⚠️ Limitación importante:** como esta página es estática (sin servidor), ese aviso diario solo se comprueba cuando alguien tiene la página abierta (lo revisa al entrar y cada 5 minutos mientras esté abierta). Si nadie abre la página ese día, no se manda nada — no hay manera de "despertar" una página estática sola. Si en algún momento se necesita que el aviso sea 100% fiable aunque nadie tenga la página abierta, haría falta montar un disparador aparte en la nube (por ejemplo, una función programada de Firebase).

### Cómo activar el envío de correos (EmailJS, gratis)

1. Ve a [emailjs.com](https://www.emailjs.com) y crea una cuenta gratuita.
2. En el panel, ve a **Email Services → Add New Service** y conecta tu cuenta de correo (Gmail, Outlook...). Apunta el **Service ID** que te genera.
3. Ve a **Email Templates → Create New Template**. En el cuerpo de la plantilla usa las variables `{{subject}}`, `{{message}}` y `{{to_email}}` (por ejemplo, asunto: `{{subject}}`, cuerpo: `{{message}}`, destinatario: `{{to_email}}`). Apunta el **Template ID**.
4. Ve a **Account → General** y copia tu **Public Key**.
5. Abre `index.html`, busca el bloque `emailjsConfig` (cerca del `firebaseConfig`) y sustituye `TU_PUBLIC_KEY`, `TU_SERVICE_ID` y `TU_TEMPLATE_ID` por los tuyos. Sube el archivo a GitHub.
6. Dentro de la app, en Almacén → panel "Avisos", pon el email al que quieres que lleguen los avisos y guarda.

Si no rellenas `emailjsConfig`, los avisos siguen apareciendo igualmente como banner dentro de la app — simplemente no se manda el correo.

## 5. Crear una orden/proyecto subiendo un archivo (Excel, CSV o PDF)

Dentro de Montaje/Venta o Proyecto, con una orden o proyecto seleccionado (y el campo "¿Quién lo pide?" relleno), en el panel lateral hay un botón **"📄 Subir Excel / CSV / PDF"**. Busca cada línea del archivo en el stock (por código o por referencia) y la añade a la **solicitud pendiente** de esa orden (ver sección 8) — no descuenta stock directamente, eso solo pasa al preparar la recogida y firmar:

- **Excel/CSV**: fiable — reconoce columnas llamadas Código, Referencia/Descripción y Cantidad (o similares).
- **PDF**: "mejor esfuerzo" — un PDF no tiene columnas de verdad, así que la app intenta sacar de cada línea de texto algo con forma de "referencia ... cantidad al final". Funciona bien con listados sencillos, pero si el PDF tiene un diseño complicado (tablas con columnas separadas visualmente, varias líneas por artículo, etc.) puede no acertar. Si falla, prueba subiendo el Excel/CSV original en su lugar.

Si una línea del archivo no coincide con ningún material del stock, la app la da de alta automáticamente como una **referencia "plantilla"** (sin stock real todavía) y la añade igualmente a la solicitud pendiente, para completarla más tarde con su código de verdad y meterle stock real.

Antes de aplicar el archivo, la app enseña un resumen línea a línea (qué hay en stock, qué queda incompleto, qué se crea como plantilla) y hay que pulsar **"Confirmar y aplicar"** — así se puede cancelar si el archivo se ha leído mal, sobre todo con PDFs complicados.

## 6. Instalar la app en el móvil (PWA)

La app ahora se puede "instalar" como si fuera una app normal del móvil, gracias a `manifest.json`, `sw.js`, `icon-192.png` e `icon-512.png` (todos incluidos en esta carpeta — súbelos junto al `index.html`, todos a la raíz del repositorio).

- **Android (Chrome)**: al entrar en la página, aparece un aviso de "Añadir a pantalla de inicio" (o menú ⋮ → "Instalar app").
- **iPhone (Safari)**: botón compartir → "Añadir a pantalla de inicio".

Una vez instalada, abre en pantalla completa (sin la barra del navegador) y guarda una copia básica en caché para que, si se corta la conexión un momento, al menos no se quede en blanco.

**Aviso de "hay una versión nueva":** cuando subas cambios en el futuro, a quien tenga la app abierta (o instalada) le aparecerá un banner abajo del todo — *"Hay una versión nueva de la app disponible"* — con un botón **"Actualizar ahora"**. Hasta que no lo pulse, sigue con la versión que ya tenía cargada; no cambia nada de golpe a media tarea.

⚠️ **Importante para que esto funcione:** cada vez que subas un `index.html` con cambios, abre `sw.js` y sube en 1 el número de la primera línea de verdad del archivo:
```js
const CACHE_NAME = 'tecnomat-materiales-v4'; // súbelo a v5, v6... cada vez que subas cambios
```
Si subes `index.html` nuevo pero te olvidas de tocar `sw.js`, el navegador no se entera de que hay nada distinto y el aviso no salta.

## 7. Tiempo real, deshacer, actividad y acciones en bloque

- **Tiempo real**: si tienes Firebase configurado, los cambios que haga otra persona desde otro dispositivo (o desde otra pestaña tuya) se ven solos, sin recargar la página.
- **Deshacer**: después de escanear algo (entrada de stock, añadir a una solicitud, añadir al pedido), sale un botón "↺ Deshacer" junto al aviso durante unos segundos, por si te equivocas.
- **Menos riesgo de perder cantidades**: cuando dos dispositivos ajustan el mismo material casi a la vez (con Firebase configurado), la app usa una transacción para que no se pise un cambio con el otro.
- **Panel "Actividad"** (dentro de Almacén): los 5 materiales que más se han movido en los últimos 30 días, con una barra sencilla.
- **Resumen semanal por correo**: además del aviso diario de stock bajo, una vez a la semana te llega un resumen con lo que más se ha movido.
- **Selección múltiple en el stock**: puedes marcar varias referencias a la vez y cambiarles la ubicación o eliminarlas todas juntas, en vez de una por una.
- **Histórico de movimientos**: en vez de borrar sin más lo que sobra de las últimas 500 líneas, se archiva resumido por mes (entradas/salidas totales), así no se pierde el dato gordo aunque no se guarde cada línea suelta.

## 8. Solicitud de taller con firma de recogida (Montaje/Venta y Proyecto)

Todo el material que se sirve desde una orden de Montaje/Venta o un Proyecto pasa por este flujo — no hay escaneo directo que descuente stock al momento, siempre queda constancia de quién lo pidió y quién lo recogió:

1. Con la orden/proyecto seleccionada, se rellena el campo **"¿Quién lo pide?"** (obligatorio — sin él no deja escanear).
2. Se escanea o busca el material necesario. Cada línea se añade a la **"Solicitud pendiente de recoger"** — esto todavía **no descuenta stock**.
3. Cuando el material está listo, se pulsa **"📝 Preparar recogida y firmar"** — en este momento la app comprueba que hay stock real de cada línea (si falta alguna, avisa y no deja continuar hasta ajustar cantidades o reponer stock).
4. Se le entrega el dispositivo a la persona del taller que recoge el material, que firma con el dedo (o el ratón) en la pantalla. Ahí se ve tanto quién lo pidió como el listado de lo que se lleva.
5. Al pulsar **"Confirmar entrega"**, es cuando de verdad se descuenta el stock y las líneas pasan a formar parte del listado "Servido" de esa orden/proyecto — hasta ese momento no se ha tocado nada, por si se cancela a mitad de camino.
6. Queda guardado un registro (quién pidió, quién recogió y firmó, qué materiales) en "Entregas firmadas" dentro de esa misma orden/proyecto, exportable a Excel.

**Nota:** el apartado **Pedido** es una cosa distinta y no lleva firma — sirve para pedir material que falta en el almacén (por ejemplo, para reponer stock desde un proveedor), y sigue funcionando como un simple listado que se manda por correo.

## 9. Restringir la clave de Firebase por dominio (recomendado, requiere consola de Google Cloud)

Esto no es un ajuste de código — es una configuración en la consola de Google, y hace falta tener acceso a esa cuenta:

1. Ve a [console.cloud.google.com](https://console.cloud.google.com) y entra con la misma cuenta de Google con la que creaste el proyecto de Firebase.
2. Arriba, asegúrate de tener seleccionado el proyecto correcto (`almacenamiento-datos-40e38`).
3. Menú ☰ → **APIs y servicios → Credenciales**.
4. Verás una clave de API (la misma que usas en `firebaseConfig`, empieza por `AIzaSy...`). Haz clic en ella.
5. En **"Restricciones de aplicaciones"**, elige **"Sitios web"** y añade tu dominio de GitHub Pages, por ejemplo:
   `tu-usuario.github.io/*`
6. Guarda.

Con esto, aunque alguien copie tu `apiKey` del código fuente, no podrá usarla desde ningún otro sitio que no sea tu propia página — una capa extra de seguridad, además de las reglas de Firestore y el login.

## 10. Cuenta de taller sin acceso a Almacén

Si alguien entra con el usuario **`taller@tecnomat.es`**, no ve la pestaña de Almacén — solo puede trabajar desde Montaje/Venta, Proyecto y Pedido. Cualquier otra cuenta (incluida `almacen@tecnomat.es`) sigue viendo todo.

**Importante — esto es una restricción de interfaz, no de seguridad de verdad.** Simplemente oculta el botón y redirige si alguien llega ahí por error; no impide técnicamente que alguien con conocimientos edite los datos saltándose la pantalla. Si quieres que sea una restricción real, hay que tocar las reglas de Firestore para que el propio servidor rechace las escrituras de esa cuenta sobre el stock. Esto sí lo puedes hacer sin tocar código:

1. Firebase Console → tu proyecto → **Firestore Database → Reglas**.
2. Sustituye las reglas actuales por estas (mismo sitio de siempre, sección 8 de este documento):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /tecnomat_materiales/catalog {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.token.email != 'taller@tecnomat.es';
       }
       match /tecnomat_materiales/movements {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.token.email != 'taller@tecnomat.es';
       }
       match /tecnomat_materiales/{docId} {
         allow read, write: if request.auth != null && docId != 'catalog' && docId != 'movements';
       }
     }
   }
   ```
3. Publicar.

Con esto, la cuenta de taller puede seguir leyendo el stock (lo necesita para que la solicitud de material compruebe cantidades disponibles), pero el propio Firestore rechaza cualquier intento de escritura sobre `catalog` o `movements` viniendo de esa cuenta — funcione o no la interfaz.

## 11. Aviso de "pedido nuevo" para almacén

Cuando alguien guarda una solicitud desde la Hoja de pedido (botón "💾 Guardar y avisar a almacén"), pasan tres cosas:

1. Se manda un correo (si tienes EmailJS configurado) con el detalle línea a línea.
2. Aparece un aviso dentro de la propia app, arriba del todo, visible para cualquiera que la tenga abierta — con el nombre de quien lo pidió, si es interno o externo, y cuántas líneas. Al pulsar sobre el aviso, te lleva directamente a esa orden/proyecto, en la pestaña de la Hoja de pedido.
3. Suena un aviso (dos pitidos) y, si has dado permiso de notificaciones al navegador, sale también una notificación del sistema — igual que la de cualquier otra app del móvil.

**Limitaciones reales:**
- Todo esto (aviso en pantalla, sonido, notificación del sistema) solo funciona con la app **abierta** en ese momento — aunque esté en segundo plano si la tienes instalada. No hay forma de que suene nada con la app completamente cerrada; para eso haría falta configurar notificaciones push de verdad (Firebase Cloud Messaging), que es una pieza bastante más grande de montar.
- El sonido depende de que el navegador permita reproducir audio — la primera vez que se abre la app, hasta que no toques la pantalla una vez (cualquier toque), el navegador puede bloquear el sonido por su propia política contra el autoplay. A partir de esa primera interacción, ya suena con normalidad el resto de la sesión.
- El correo sí llega siempre, esté la app abierta o no — es lo único 100% fiable de los tres avisos.

## 12. Interno / Externo

Al crear una orden de Montaje/Venta o un proyecto, además del nombre y de quién pide el material, hay que indicar si es **Interno** o **Externo** — es obligatorio, igual que los otros dos campos. Se ve junto al nombre en el desplegable de selección, en la cabecera de la Hoja de pedido, y en el correo y aviso de pedido nuevo.

## 13. Sobre el logo en los Excel exportados

Las exportaciones a Excel (stock, movimientos, órdenes, entregas...) llevan **"TECNOMAT · Control de materiales"** como texto en la primera fila de cada hoja. No es el logo como imagen — la librería gratuita que usa la app para generar Excel (SheetJS) no permite insertar imágenes dentro del archivo, esa función es de pago en esa librería.

Si en algún momento necesitas el logo real como imagen dentro del Excel, la vía sería partir de una plantilla `.xlsx` vuestra que ya tenga el logo puesto, y rellenar los datos dentro de esa plantilla en lugar de generar el archivo desde cero — es un planteamiento distinto y bastante más laborioso de montar.

## 14. Rendimiento con inventarios grandes

Con inventarios de miles de referencias, la lista de Almacén ahora solo pinta 80 a la vez, con un botón **"Cargar más"** al final para ver el resto — antes se pintaban todas de golpe, lo cual notaba lento con inventarios grandes (más aún con el estilo de esquina cortada del rediseño, que es más costoso de dibujar que un botón normal cuando se repite cientos de veces). Los botones de cada fila del stock (Cambiar ubicación, Categoría, Cantidad, Eliminar...) volvieron a un estilo más simple por el mismo motivo — el aspecto de "esquina cortada" se queda en las tarjetas, pestañas y botones principales, que aparecen pocas veces en pantalla, no en los que se repiten por cada artículo.


