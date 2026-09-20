// Workspace safety helpers shared by IPC handlers (pure, unit-testable).

const path = require('path');

// Resolve a relative path inside a workspace, rejecting any escape (e.g. `../`).
function resolveInsideWorkspace(workspacePath, relativePath) {
  const root = path.resolve(workspacePath);
  const full = path.resolve(root, relativePath || '');
  if (full !== root && !full.startsWith(root + path.sep)) {
    throw new Error(`Path "${relativePath}" escapes the workspace boundary.`);
  }
  return full;
}

// Commands the agent may never run regardless of permissions.
const DENIED_COMMAND_PATTERNS = [
  /\brm\s+(-[a-zA-Z]*\s+)*-?[a-zA-Z]*[rfR][a-zA-Z]*\s+\/(\s|$)/, // rm -rf /
  /\bsudo\b/,
  /curl[^|]*\|\s*(ba)?sh\b/,
  /wget[^|]*\|\s*(ba)?sh\b/,
  /\bmkfs\b/,
  /\bdd\s+.*of=\/dev\//
];

function isCommandDenied(command) {
  return DENIED_COMMAND_PATTERNS.some((re) => re.test(command));
}

// Simple unified line diff (LCS-based) for before/after file contents.
function computeLineDiff(before, after) {
  const a = before ? before.split('\n') : [];
  const b = after ? after.split('\n') : [];
  // LCS table (capped to avoid pathological memory use on huge files)
  const MAX = 4000;
  const ax = a.slice(0, MAX), bx = b.slice(0, MAX);
  const table = Array.from({ length: ax.length + 1 }, () => new Uint32Array(bx.length + 1));
  for (let i = ax.length - 1; i >= 0; i--) {
    for (let j = bx.length - 1; j >= 0; j--) {
      table[i][j] = ax[i] === bx[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  const hunks = [];
  let i = 0, j = 0, aStart = 0, bStart = 0;
  let pending = [];
  const flush = () => {
    if (pending.length) {
      hunks.push({ aStart: aStart + 1, bStart: bStart + 1, lines: pending });
      pending = [];
    }
  };
  while (i < ax.length && j < bx.length) {
    if (ax[i] === bx[j]) {
      flush();
      i++; j++; aStart = i; bStart = j;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      pending.push({ type: 'del', text: ax[i] }); i++;
    } else {
      pending.push({ type: 'add', text: bx[j] }); j++;
    }
  }
  while (i < ax.length) { pending.push({ type: 'del', text: ax[i] }); i++; }
  while (j < bx.length) { pending.push({ type: 'add', text: bx[j] }); j++; }
  flush();
  return {
    truncated: a.length > MAX || b.length > MAX,
    hunks,
    added: hunks.reduce((n, h) => n + h.lines.filter(l => l.type === 'add').length, 0),
    removed: hunks.reduce((n, h) => n + h.lines.filter(l => l.type === 'del').length, 0)
  };
}

module.exports = { resolveInsideWorkspace, isCommandDenied, DENIED_COMMAND_PATTERNS, computeLineDiff };
