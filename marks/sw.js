const CACHE_NAME = 'smartscan-cache-v1';
const INITIAL_CACHED_RESOURCES = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon.svg'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('Opened cache and caching initial resources');
      return cache.addAll(INITIAL_CACHED_RESOURCES);
    })
  );
});

self.addEventListener('fetch', event => {
  // We only want to cache GET requests.
  if (event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    caches.match(event.request).then(cachedResponse => {
      // Return the cached response if it's found
      if (cachedResponse) {
        return cachedResponse;
      }
      
      // If not in cache, fetch it from the network
      return fetch(event.request).then(networkResponse => {
          if(!networkResponse || networkResponse.status !== 200) {
              return networkResponse;
          }

          // Clone the response because it's a one-time-use stream
          const responseToCache = networkResponse.clone();

          caches.open(CACHE_NAME).then(cache => {
              cache.put(event.request, responseToCache);
          });

          return networkResponse;
      }).catch(error => {
          console.error('Fetching failed:', error);
          throw error;
      });
    })
  );
});

self.addEventListener('activate', event => {
  const cacheWhitelist = [CACHE_NAME];
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheWhitelist.indexOf(cacheName) === -1) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});