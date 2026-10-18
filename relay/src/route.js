// Shared by the Pages Function (production) and the relay Worker's own fetch (local tests only:
// in production the Worker has no route). Cheap checks happen here, before a Durable Object request.

const CODE = /^[1-9][0-9]{3}$/;
const BUILD = /^[\w.-]{1,40}$/;
// A random 4-digit code is taken while its room is open; a few tries find a free one.
const CREATE_TRIES = 8;

export async function routeRoom(request, env, code) {
	if (request.headers.get('Upgrade') !== 'websocket') {
		return new Response('Expected a WebSocket', { status: 426 });
	}
	const url = new URL(request.url);
	if (!BUILD.test(url.searchParams.get('build') || '')) {
		return new Response('Missing build', { status: 400 });
	}
	if (code === 'new') {
		for (let i = 0; i < CREATE_TRIES; i++) {
			const candidate = String(1000 + Math.floor(Math.random() * 9000));
			const response = await forward(request, env, candidate, true);
			if (response.status !== 409) {
				return response;
			}
		}
		return new Response('No free room code', { status: 503 });
	}
	if (!CODE.test(code)) {
		return new Response('Bad room code', { status: 404 });
	}
	return forward(request, env, code, false);
}

function forward(request, env, code, create) {
	const url = new URL(request.url);
	url.searchParams.set('code', code);
	url.searchParams.set('create', create ? '1' : '0');
	const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
	return stub.fetch(new Request(url, request));
}
