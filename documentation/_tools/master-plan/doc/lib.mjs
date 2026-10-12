// Tiny document model: one source, two outputs (Markdown for the repo, HTML for the PDF).
export class Doc {
  constructor() { this.b = []; }
  h(level, text, id) { this.b.push({ t: 'h', level, text, id }); return this; }
  p(text) { this.b.push({ t: 'p', text }); return this; }
  ul(items) { if (items && items.length) this.b.push({ t: 'ul', items }); return this; }
  ol(items) { if (items && items.length) this.b.push({ t: 'ol', items }); return this; }
  table(head, rows, opts = {}) { if (rows && rows.length) this.b.push({ t: 'table', head, rows, opts }); return this; }
  code(text, lang = '') { this.b.push({ t: 'code', text, lang }); return this; }
  note(text, kind = 'note') { this.b.push({ t: 'note', text, kind }); return this; }
  pagebreak() { this.b.push({ t: 'pb' }); return this; }
  raw(md, html) { this.b.push({ t: 'raw', md, html }); return this; }

  toc() { return this.b.filter(x => x.t === 'h' && x.level <= 2); }

  static slug(s) { return String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''); }
  static esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  static inl(s) { // **bold**, `code`, [text](url)
    let x = Doc.esc(s);
    x = x.replace(/`([^`]+)`/g, '<code>$1</code>').replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>').replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    return x;
  }
  static mdCell(s) { return String(s == null ? '' : s).replace(/\|/g, '\\|').replace(/\n/g, '<br>'); }

  md() {
    const out = [];
    for (const x of this.b) {
      if (x.t === 'h') out.push('#'.repeat(x.level) + ' ' + x.text + '\n');
      else if (x.t === 'p') out.push(x.text + '\n');
      else if (x.t === 'ul') out.push(x.items.map(i => '- ' + i).join('\n') + '\n');
      else if (x.t === 'ol') out.push(x.items.map((i, n) => (n + 1) + '. ' + i).join('\n') + '\n');
      else if (x.t === 'table') {
        out.push('| ' + x.head.map(Doc.mdCell).join(' | ') + ' |\n|' + x.head.map(() => '---').join('|') + '|\n' + x.rows.map(r => '| ' + r.map(Doc.mdCell).join(' | ') + ' |').join('\n') + '\n');
      } else if (x.t === 'code') out.push('```' + x.lang + '\n' + x.text + '\n```\n');
      else if (x.t === 'note') out.push('> **' + ({ note: 'Note', rule: 'Rule', warn: 'Careful', key: 'Remember' }[x.kind] || 'Note') + ':** ' + x.text + '\n');
      else if (x.t === 'raw') out.push(x.md + '\n');
    }
    return out.join('\n');
  }

  html(title) {
    const out = [];
    for (const x of this.b) {
      if (x.t === 'h') out.push(`<h${x.level}${x.id ? ' id="' + x.id + '"' : ''}>${Doc.inl(x.text)}</h${x.level}>`);
      else if (x.t === 'p') out.push(`<p>${Doc.inl(x.text)}</p>`);
      else if (x.t === 'ul') out.push('<ul>' + x.items.map(i => `<li>${Doc.inl(i)}</li>`).join('') + '</ul>');
      else if (x.t === 'ol') out.push('<ol>' + x.items.map(i => `<li>${Doc.inl(i)}</li>`).join('') + '</ol>');
      else if (x.t === 'table') out.push('<table><thead><tr>' + x.head.map(h => `<th>${Doc.inl(h)}</th>`).join('') + '</tr></thead><tbody>' + x.rows.map(r => '<tr>' + r.map(c => `<td>${Doc.inl(c).replace(/\n/g, '<br>')}</td>`).join('') + '</tr>').join('') + '</tbody></table>');
      else if (x.t === 'code') out.push(`<pre>${Doc.esc(x.text)}</pre>`);
      else if (x.t === 'note') out.push(`<div class="note ${x.kind}"><b>${{ note: 'Note', rule: 'Rule', warn: 'Careful', key: 'Remember' }[x.kind] || 'Note'}:</b> ${Doc.inl(x.text)}</div>`);
      else if (x.t === 'pb') out.push('<div class="pb"></div>');
      else if (x.t === 'raw') out.push(x.html);
    }
    return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${Doc.esc(title)}</title><style>
@page{size:A4;margin:14mm 12mm}
*{box-sizing:border-box}
body{font:10.5px/1.5 -apple-system,"Segoe UI",Roboto,Arial,sans-serif;color:#0f172a;margin:0;padding:0}
h1{font-size:26px;color:#0B2A4A;margin:0 0 6px}
h2{font-size:18px;color:#fff;background:linear-gradient(90deg,#0B2A4A,#1A73E8);padding:7px 12px;border-radius:6px;margin:26px 0 10px;page-break-after:avoid}
h3{font-size:14px;color:#0B2A4A;border-bottom:2px solid #1A73E8;padding-bottom:3px;margin:20px 0 8px;page-break-after:avoid}
h4{font-size:12px;color:#0B2A4A;margin:14px 0 5px;page-break-after:avoid}
h5{font-size:11px;color:#334155;margin:10px 0 4px;page-break-after:avoid}
p{margin:5px 0 7px}
ul,ol{margin:4px 0 8px 18px;padding:0}li{margin:2px 0}
table{border-collapse:collapse;width:100%;margin:6px 0 12px;font-size:9.5px;page-break-inside:auto}
tr{page-break-inside:avoid}
th{background:#0B2A4A;color:#fff;text-align:left;padding:4px 6px;font-weight:600}
td{border:1px solid #cbd5e1;padding:3px 6px;vertical-align:top}
tbody tr:nth-child(even) td{background:#f1f5f9}
code{background:#e8f0fe;color:#0B2A4A;padding:0 3px;border-radius:3px;font:9px Consolas,monospace}
pre{background:#0f172a;color:#e2e8f0;padding:9px 11px;border-radius:6px;font:9px/1.45 Consolas,monospace;white-space:pre-wrap;page-break-inside:avoid}
.note{border-left:4px solid #1A73E8;background:#eff6ff;padding:6px 10px;margin:8px 0;border-radius:0 6px 6px 0}
.note.rule{border-color:#0F9D58;background:#ecfdf5}.note.warn{border-color:#E8710A;background:#fff7ed}.note.key{border-color:#7c3aed;background:#f5f3ff}
.pb{page-break-after:always}
.cover{padding:60px 0 30px}.cover .sub{font-size:14px;color:#475569}
a{color:#1A73E8;text-decoration:none}
</style></head><body>${out.join('\n')}</body></html>`;
  }
}
