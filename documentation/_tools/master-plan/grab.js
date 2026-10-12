(async function () {
  window.__cap = window.__cap || {};
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const txt = e => (e.textContent || '').replace(/\s+/g, ' ').trim();
  const SKIP = /^(nav|go|menu|theme|bell|acct|lang|lang_sel|role|signout|gsearch|demo_toggle|kpi|tab|t_pg|t_clr|t_clr_sel|sim|sim_ok|ev|relogin|mfa|mfa_ok|undo|chart_pt|t_sort|t_sel|t_all|t_chk|mdl_x|mdl_bg)$/;
  window.__grab = async function (allowNav, doTabs) {
    const page = {};
    page.heading = txt(document.querySelector('h1,.ph h2,.pg-h,header h1') || document.body).slice(0, 80);
    page.kpis = [...document.querySelectorAll('[data-a=kpi]')].map(e => txt(e).slice(0, 70));
    page.tabs = [...new Set([...document.querySelectorAll('[data-a=tab]')].map(e => txt(e)))];
    page.tables = [...document.querySelectorAll('table')].map(t => [...t.querySelectorAll('thead th')].map(th => txt(th)).filter(Boolean));
    page.filters = [...document.querySelectorAll('select, input:not([type=checkbox])')].filter(e => e.getBoundingClientRect().width > 0 && !e.closest('#modalRoot')).map(e => {
      const l = e.getAttribute('aria-label') || e.placeholder || (e.labels && e.labels[0] ? txt(e.labels[0]) : '') || e.id;
      return e.tagName === 'SELECT' ? l + ' [' + [...e.options].slice(0, 10).map(o => o.text).join(' / ') + ']' : l;
    }).filter((x, i, a) => x && a.indexOf(x) === i).slice(0, 25);
    const els = [...document.querySelectorAll('[data-a]')].filter(e => e.getBoundingClientRect().width > 0 && !e.closest('#modalRoot') && !e.closest('aside,nav,.sb,.side') && !SKIP.test(e.dataset.a));
    const seen = new Set(), acts = [];
    for (const e of els) {
      const k = e.dataset.a + '|' + txt(e).slice(0, 30);
      if (seen.has(k) || seen.size > 60) continue;
      seen.add(k);
      acts.push({ a: e.dataset.a, label: txt(e).slice(0, 40) || e.getAttribute('aria-label') || '', row: !!e.closest('tbody') });
    }
    page.actions = [];
    for (const x of acts) {
      let cand = null;
      for (let tr = 0; tr < 6 && !cand; tr++) {
        cand = [...document.querySelectorAll('[data-a="' + x.a + '"]')].find(e => (txt(e).slice(0, 40) || e.getAttribute('aria-label') || '') === x.label && e.getBoundingClientRect().width > 0);
        if (!cand) await sleep(250);
      }
      if (!cand) { page.actions.push({ ...x, kind: 'gone' }); continue; }
      const h0 = location.hash;
      try { cand.dispatchEvent(new MouseEvent('click', { bubbles: true })); } catch (er) { page.actions.push({ ...x, kind: 'error', err: String(er).slice(0, 60) }); continue; }
      await sleep(80);
      const m = document.querySelector('#modalRoot .md');
      if (m) {
        const fields = [...m.querySelectorAll('.bd2 .fd')].map(f => {
          const l = f.querySelector('label'), c = f.querySelector('input,select,textarea');
          return { label: l ? txt(l) : '', type: c ? (c.tagName === 'SELECT' ? 'select' : c.tagName === 'TEXTAREA' ? 'textarea' : c.type || 'text') : '', opts: c && c.tagName === 'SELECT' ? [...c.options].slice(0, 12).map(o => o.text) : undefined };
        }).filter(f => f.label);
        const foot = [...m.querySelectorAll('footer [data-a]')].map(e => ({ a: e.dataset.a, label: txt(e) }));
        page.actions.push({ ...x, kind: 'dialog', title: txt(m.querySelector('header h3') || m).slice(0, 70), fields, foot, body: fields.length ? '' : txt(m.querySelector('.bd2')).slice(0, 160) });
        if (typeof closeModal === 'function') closeModal();
      } else if (location.hash !== h0) {
        const to = location.hash;
        page.actions.push({ ...x, kind: 'navigates', to });
        const pat = to.replace(/[A-Z]{2,4}-?\d+[A-Z0-9-]*/g, ':id').replace(/\/[A-Za-z0-9_-]*\d[A-Za-z0-9_-]*$/, '/:id');
        if (allowNav && !window.__cap[pat]) {
          window.__cap[pat] = 1;
          await sleep(800);
          const sub = await window.__grab(false, true);
          page.details = page.details || [];
          page.details.push({ route: pat, ...sub });
        }
        location.hash = h0;
        await sleep(900);
      } else page.actions.push({ ...x, kind: 'direct' });
      await sleep(40);
    }
    if (doTabs && page.tabs.length > 1) {
      page.tabPages = [];
      for (const tl of page.tabs) {
        const te = [...document.querySelectorAll('[data-a=tab]')].find(e => txt(e) === tl && e.getBoundingClientRect().width > 0);
        if (!te) continue;
        te.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        await sleep(450);
        const sub = await window.__grab(false, false);
        page.tabPages.push({ tab: tl, ...sub });
      }
      const t0 = [...document.querySelectorAll('[data-a=tab]')].find(e => e.getBoundingClientRect().width > 0);
      if (t0) { t0.dispatchEvent(new MouseEvent('click', { bubbles: true })); await sleep(300); }
    }
    return page;
  };
  return await window.__grab(true, true);
})()
