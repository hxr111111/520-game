// Service Worker — 离线缓存版本
const CACHE = 'yuyu-v1';

// 需要缓存的文件
const PRECACHE = [
  './',
  './小游戏.html',
  './manifest.json',
  './icon.svg',
  './share-cover.svg',
];

// ── 安装：预缓存所有资源 ──
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

// ── 激活：清理旧版本缓存 ──
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// ── 拦截请求：优先缓存，无网络时降级 ──
self.addEventListener('fetch', event => {
  // 只处理同源 GET 请求
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      // 网络请求并顺手更新缓存
      return fetch(event.request).then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE).then(c => c.put(event.request, clone));
        }
        return response;
      }).catch(() =>
        // 完全离线时返回主页面
        caches.match('./小游戏.html')
      );
    })
  );
});
