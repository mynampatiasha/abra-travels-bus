import fs from 'fs';
for (const app of ['admin', 'client']) {
  const parts = fs.readdirSync('.').filter(f => new RegExp('^map_' + app + '_[0-9]+\\.json$').test(f)).sort((a, b) => parseInt(a.match(/[0-9]+/)[0]) - parseInt(b.match(/[0-9]+/)[0]));
  const all = { app, roles: null, perm: null, pages: [] };
  for (const f of parts) { const j = JSON.parse(fs.readFileSync(f)); all.roles = all.roles || j.roles; all.perm = all.perm || j.perm; all.pages.push(...j.pages); }
  fs.writeFileSync('all_' + app + '.json', JSON.stringify(all));
  console.log(app, parts.join(','), all.pages.length, 'pages', all.pages.filter(p => p.error).map(p => p.id + ':ERR').join(' '));
}
