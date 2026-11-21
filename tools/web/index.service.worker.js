// Desliga o service worker antigo (PWA) de quem já abriu o jogo.
// O PWA servia a versão guardada no aparelho primeiro, então um deploy novo
// ficava escondido até a pessoa fechar todas as abas. Este arquivo substitui o
// antigo no mesmo endereço: o navegador encontra a versão nova, ela apaga os
// caches, se desregistra e recarrega as abas abertas já com a versão atual.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		await Promise.all(keys.map((k) => caches.delete(k)));
		await self.registration.unregister();
		const clients = await self.clients.matchAll({ type: 'window' });
		for (const c of clients) {
			c.navigate(c.url);
		}
	})());
});
