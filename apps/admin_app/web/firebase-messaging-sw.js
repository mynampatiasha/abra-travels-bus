// Shows a notification when a push arrives while the portal is closed.
// Firebase web config values are public identifiers, not secrets.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAR7ot7EBikOWOxEPPFEntqiuL3bsuZavI',
  appId: '1:626328346112:web:7a2e5c1e217607a25482e5',
  messagingSenderId: '626328346112',
  projectId: 'abra-travels',
  authDomain: 'abra-travels.firebaseapp.com',
  storageBucket: 'abra-travels.firebasestorage.app',
});

const messaging = firebase.messaging();

// Messages with a "notification" block are shown by the browser itself; this
// covers data-only messages.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  self.registration.showNotification(data.title || 'Abra Travels', {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    data: { route: data.route || '/' },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  // A message the browser showed itself keeps its data under FCM_MSG; one this worker showed
  // keeps it directly.
  const raw = event.notification.data || {};
  const fcm = (raw.FCM_MSG && raw.FCM_MSG.data) || {};
  const route = raw.route || fcm.route || '/';
  const target = self.location.origin + '/#' + route;
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if ('focus' in client) {
          return client.focus().then(() => ('navigate' in client ? client.navigate(target) : client));
        }
      }
      return clients.openWindow(target);
    }),
  );
});
