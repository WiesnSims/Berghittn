// https://berghittn.pages.dev/api/board/<ticket|entry|list>: das Gipfelbuch, the global leaderboard.
import { handleBoard } from '../../../board/board.js';

export const onRequest = ({ request, env, params }) => handleBoard(request, env, params.action);
