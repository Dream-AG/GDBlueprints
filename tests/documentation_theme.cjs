// Test the shipped theme scripts without requiring a browser or network.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '../documentation');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const init = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const script = fs.readFileSync(path.join(root, 'assets/manual.js'), 'utf8');
for (const dark of [false, true]) {
  for (const stored of [null, 'dark', 'light']) {
    for (const blocked of [false, true]) {
      let click;
      let saved;
      const toggle = {setAttribute(k,v) { this[k] = v; }, addEventListener(k, fn) { click = fn; }};
      const context = {
        document: {documentElement: {dataset: {}}, querySelector: q => q === '#theme-toggle' ? toggle : null, querySelectorAll: () => []},
        localStorage: {getItem() { if (blocked) throw Error('blocked'); return stored; }, setItem(k,v) { if (blocked) throw Error('blocked'); saved = v; }},
        matchMedia: () => ({matches: dark}),
      };
      vm.createContext(context);
      vm.runInContext(init, context);
      vm.runInContext(script, context);
      const initial = !blocked && stored ? stored : dark ? 'dark' : 'light';
      assert.equal(context.document.documentElement.dataset.theme, initial);
      click();
      assert.equal(context.document.documentElement.dataset.theme, initial === 'dark' ? 'light' : 'dark');
      assert.equal(toggle['aria-pressed'], String(initial !== 'dark'));
      if (!blocked) assert.equal(saved, initial === 'dark' ? 'light' : 'dark');
    }
  }
}
console.log('Documentation theme: 12 system/stored/blocked-storage cases passed.');
