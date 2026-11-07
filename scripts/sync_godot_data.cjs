// Keep card values and boss definitions grounded in the original web game.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'web/game.js'), 'utf8');
const context = vm.createContext({});
function extract(start, end, name) {
  const from = source.indexOf(start);
  const to = source.indexOf(end, from);
  if (from < 0 || to < 0) throw new Error(`Definition not found: ${name}`);
  vm.runInContext(source.slice(from, to) + `this.result = ${name};`, context);
  return context.result;
}
const definitions = {
  cards: extract('const C=', 'const BASE=', 'C'),
  stages: extract('const STAGES=', 'function currentStage', 'STAGES'),
};
for (const [name, data] of Object.entries(definitions)) {
  fs.writeFileSync(path.join(root, 'godot/assets', `${name}.json`), JSON.stringify(data));
}
console.log('Godot: 24 cards and 5 bosses synchronized with web/game.js.');
