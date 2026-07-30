   # Tecnomat · Control de Materiales

App de gestión de stock, montaje y proyectos con escaneo de código de barras (lector USB/Bluetooth o cámara del móvil), pensada para funcionar como una única página web (`index.html`).

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

La app detecta automáticamente dónde se está ejecutando:

- **Dentro de Claude.ai**: usa el guardado en la nube de Anthropic.
- **Alojada en GitHub Pages (o cualquier otro sitio)**: usa `localStorage`, la memoria propia del navegador. Sigue guardándose todo solo, sin que tengas que hacer nada — pero **queda guardado en ese navegador y dispositivo concretos**, no en un servidor compartido.

Esto significa que si entras desde el móvil del almacén y luego desde el ordenador de la oficina, cada uno tendrá su propio stock guardado por separado — no se sincronizan automáticamente entre sí.

**Recomendación:** usa el botón **"⬇ Descargar todo"** (dentro del modo Almacén) de vez en cuando para bajarte una copia de seguridad real en un archivo `.json`, y **"⬆ Restaurar"** si necesitas pasar esos datos a otro dispositivo o recuperarlos tras borrar el navegador.

## 3. ¿Se puede tener un backend real en GitHub?

**No.** GitHub Pages solo sirve archivos estáticos (HTML, CSS, JavaScript) — no puede ejecutar un servidor, ni una base de datos, ni código en segundo plano. Por eso el guardado ahí depende del navegador (`localStorage`) y no hay sincronización automática entre dispositivos.

Si en el futuro necesitas que **varios dispositivos vean y actualicen el mismo stock en tiempo real** (por ejemplo, dos operarios escaneando a la vez desde distintos móviles), la app seguiría alojada gratis en GitHub Pages, pero necesitaría conectarse a un servicio externo que sí ofrezca base de datos, como **Firebase** (el más sencillo y con capa gratuita más que suficiente para este uso) o **Supabase**. Requeriría:

1. Crear una cuenta gratuita en Firebase (o Supabase).
2. Crear un proyecto y activar su base de datos.
3. Pegar la configuración del proyecto en el código de la app (unas pocas líneas).

Es una integración que puedo preparar en el propio código en cuanto quieras — solo hace falta que crees la cuenta gratuita y me pases la configuración del proyecto.
