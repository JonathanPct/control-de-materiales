// service worker mínimo — lo único que quiero es que la app se pueda "instalar"
// en el móvil y que, si en algún momento no hay conexión, al menos abra desde caché
// en vez de quedarse en blanco. No hago nada más raro que eso.
//
// cuando suba un index.html nuevo, cambio este número de versión — eso es lo que
// hace que el navegador detecte que hay un service worker distinto y arranque
// el proceso de actualización (que luego el propio index.html avisa al usuario)
const CACHE_NAME = 'tecnomat-materiales-v5';
const APP_SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', event => {
  // cacheo el "esqueleto" de la app nada más instalarse
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL))
  );
  // ya NO hago self.skipWaiting() aquí — quiero que la versión nueva se quede
  // "esperando" hasta que el usuario pulse el aviso de "Actualizar ahora" en la
  // propia app, en vez de cambiar la versión activa sin avisar a mitad de sesión
});

self.addEventListener('activate', event => {
  // limpio cachés de versiones antiguas
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// esto es lo que dispara el "Actualizar ahora" del banner: la página le manda
// este mensaje al service worker nuevo (que estaba esperando) y aquí le digo
// que pase a ser el activo
self.addEventListener('message', event => {
  if(event.data === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', event => {
  // solo intercepto peticiones GET — el resto (POST a Firebase, etc.) lo dejo pasar tal cual
  if(event.request.method !== 'GET') return;

  event.respondWith(
    fetch(event.request)
      .then(resp => {
        // si ha ido bien por red, aprovecho y actualizo la copia en caché
        const clone = resp.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        return resp;
      })
      .catch(() => caches.match(event.request)) // sin conexión, tiro de lo que tenga cacheado
  );
});
