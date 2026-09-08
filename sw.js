/* 氣墊樂園 PWA service worker
   策略：永遠先抓網路（確保時段、設定、config 都是最新），沒網路時才用快取。 */
const CACHE = 'aircastle-v1';
const SHELL = ['./', './index.html', './admin.html', './config.js', './key-visual.jpg', './manifest.json', './icon-192.png', './icon-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).catch(()=>{})); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k!==CACHE).map(k => caches.delete(k))))); self.clients.claim(); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || !e.request.url.startsWith(self.location.origin)) return;   // Supabase / GA 等外部請求不碰
  e.respondWith(fetch(e.request).then(r => { const copy=r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r; })
    .catch(() => caches.match(e.request, { ignoreSearch:true })));
});
