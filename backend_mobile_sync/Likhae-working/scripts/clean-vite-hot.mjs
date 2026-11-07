import { rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const hotFile = fileURLToPath(new URL('../storage/framework/vite.hot', import.meta.url));
const legacyHotFile = fileURLToPath(new URL('../public/hot', import.meta.url));

rmSync(hotFile, { force: true });
rmSync(legacyHotFile, { force: true });
