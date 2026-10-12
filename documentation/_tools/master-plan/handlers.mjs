import fs from 'fs';
const app = process.argv[2];
const j = JSON.parse(fs.readFileSync('all_' + app + '.json'));
const H = {};
const add = (page, a, tag) => {
  const h = H[a.a] = H[a.a] || { pages: new Set(), labels: new Set(), dlg: null, foot: new Set(), kinds: new Set() };
  h.pages.add(page + (tag ? '#' + tag : ''));
  if (a.label) h.labels.add(a.label.slice(0, 22));
  h.kinds.add(a.kind || 'footer');
  if (a.kind === 'dialog' && !h.dlg) h.dlg = a.title + (a.fields && a.fields.length ? ' {' + a.fields.map(f => f.label.replace(/\s*\*/, '*')).join(', ') + '}' : (a.body ? ' "' + a.body.slice(0, 60) + '"' : ''));
  (a.foot || []).forEach(f => { h.foot.add(f.a); add(page, { a: f.a, label: f.label, kind: 'footer' }, tag); });
};
const walk = (page, p, tag) => {
  (p.actions || []).forEach(a => add(page, a, tag));
  (p.tabPages || []).forEach(t => walk(page, t, (tag ? tag + '/' : '') + 'tab:' + t.tab));
  (p.details || []).forEach(d => walk(page, d, 'detail'));
};
j.pages.forEach(p => walk(p.id, p, ''));
const src = fs.readFileSync('D:/New_project/abra-travels/prototypes/' + app + '_demo_model.html', 'utf8');
const all = new Set([...src.matchAll(/(?:^|[;\n}])\s*A\.([A-Za-z_0-9]+)\s*=/g)].map(m => m[1]));
for (const m of src.matchAll(/^\s*([a-z_0-9]+):\s*(?:async\s*)?\(?[a-z,\s]*\)?\s*=>/gm)) all.add(m[1]);
const names = [...new Set([...Object.keys(H), ...all])].sort();
const out = [];
for (const n of names) {
  const h = H[n];
  out.push(n + ' | ' + (h ? [...h.pages].slice(0, 4).join(',') + ' | ' + [...h.labels].slice(0, 2).join('/') + (h.dlg ? ' | DLG ' + h.dlg.slice(0, 160) : '') : 'NOT ON ANY CAPTURED PAGE'));
}
fs.writeFileSync('handlers_' + app + '.txt', out.join('\n'));
console.log(app, names.length, 'handlers,', Object.keys(H).length, 'seen on pages');
