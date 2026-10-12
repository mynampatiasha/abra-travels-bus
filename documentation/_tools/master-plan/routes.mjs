import fs from 'fs';
import path from 'path';
const root = 'D:/New_project/abra-travels/backend/src';
const files = [];
(function walk(d) { for (const f of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, f.name); if (f.isDirectory()) { if (!/node_modules|tests?$/.test(f.name)) walk(p); } else if (/controller\.ts$/.test(f.name)) files.push(p); } })(root);
const out = [];
for (const f of files) {
  const s = fs.readFileSync(f, 'utf8');
  const c = s.match(/@Controller\(\s*(?:\{[^}]*path:\s*)?['"`]([^'"`]*)['"`]/);
  const base = c ? c[1] : '';
  const mod = path.relative(root, f).split(path.sep)[1];
  for (const m of s.matchAll(/@(Get|Post|Put|Patch|Delete)\(\s*(?:['"`]([^'"`]*)['"`])?\s*\)/g)) {
    out.push({ module: mod, method: m[1].toUpperCase(), path: ('/' + base + '/' + (m[2] || '')).replace(/\/+/g, '/').replace(/\/$/, '') || '/' });
  }
}
fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 1));
const by = {};
out.forEach(r => (by[r.module] = (by[r.module] || 0) + 1));
console.log(files.length, 'controllers,', out.length, 'routes');
console.log(JSON.stringify(by));
