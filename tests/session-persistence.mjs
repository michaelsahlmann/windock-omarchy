/**
 * Checks the session store added by persistent-sessions.patch.
 *
 * Usage:
 *   node session-persistence.mjs /usr/lib/windock/src/auth.js
 *
 * Point it at a patched auth.js. It writes a throwaway file next to itself
 * and removes it at the end.
 */

import { rmSync, existsSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const authPath = process.argv[2];
if (!authPath) {
  console.error("usage: node session-persistence.mjs /path/to/patched/auth.js");
  process.exit(2);
}

const { createSessionStore } = await import(authPath);

const here = dirname(fileURLToPath(import.meta.url));
const file = join(here, ".sessions-test.json");
rmSync(file, { force: true });

const results = [];
function check(name, actual, expected) {
  const pass = actual === expected;
  results.push(pass);
  console.log(`${pass ? "ok  " : "FAIL"} ${name}: ${actual}`);
}

const first = createSessionStore({ file });
const token = first.issue();
check("token issued", token.length > 20, true);
check("file created", existsSync(file), true);
check("file mode 600", (statSync(file).mode & 0o777).toString(8), "600");

// A fresh store over the same file is what a process restart looks like.
const restarted = createSessionStore({ file });
check("survives restart", restarted.verify(token), true);

// No file keeps the upstream behaviour: sessions live in memory only.
const memoryOnly = createSessionStore();
check("no file means no persistence", memoryOnly.verify(token), false);

check("unknown token rejected", restarted.verify("not-a-token"), false);

restarted.revokeAll();
const afterRevoke = createSessionStore({ file });
check("revokeAll persists", afterRevoke.verify(token), false);

rmSync(file, { force: true });
const expired = createSessionStore({ file, ttlMs: -1 });
const stale = expired.issue();
const reloaded = createSessionStore({ file });
check("expired token dropped on load", reloaded.verify(stale), false);

rmSync(file, { force: true });

const failed = results.filter((r) => !r).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed === 0 ? 0 : 1);
