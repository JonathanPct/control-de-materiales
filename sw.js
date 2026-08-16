// service worker mínimo — lo único que quiero es que la app se pueda "instalar"
// en el móvil y que, si en algún momento no hay conexión, al menos abra desde caché
// en vez de quedarse en blanco. No hago nada más raro que eso.

const CACHE_NAME = 'tecnomat-materiales-v1';
const APP_SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', event => {
  // cacheo el "esqueleto" de la app nada más instalarse
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  // limpio cachés de versiones antiguas si algún día cambio el nombre de CACHE_NAME
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
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
