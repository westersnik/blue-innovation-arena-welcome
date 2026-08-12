import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('..', import.meta.url);
const read = (path) => readFile(new URL(path, root), 'utf8');

const [schema, claims, config, display, cupPage, relay] = await Promise.all([
  read('supabase/migrations/20260811_multi_event_configuration.sql'),
  read('supabase/migrations/20260812_event_scoped_claims.sql'),
  read('konfigurasjon.html'),
  read('storskjerm.html'),
  read('V2/index.html'),
  read('supabase/functions/rfid-relay/index.ts'),
]);

assert.match(schema, /coffee-batch-1[\s\S]*'coffee'/, 'Batch 1 must be declared as coffee');
assert.match(schema, /coffee-batch-2[\s\S]*'coffee'/, 'Batch 2 must be declared as coffee');
assert.match(schema, /product_mode TEXT NOT NULL CHECK \(product_mode IN \('coffee','beer'\)\)/, 'Future batches must declare coffee or beer');
assert.match(schema, /status IN \('allocated','registered','recycled','released'\)/, 'Allocation lifecycle must preserve used cups and release untouched cups');
assert.match(schema, /UPDATE event_cups SET status='released'/, 'Closing an event must release unused cups');
assert.match(claims, /claim_event_cup/, 'Configured event claims must use server-side allocation checks');
assert.match(config, /Avslutt arrangement\?/, 'Configuration UI must require closure confirmation');
assert.match(config, /create_event_session/, 'Configuration UI must create events via the allocation function');
assert.match(config, /close_event_session/, 'Configuration UI must close events via the lifecycle function');
assert.match(display, /event-progress/, 'Storskjerm must contain the configurable event progress interface');
assert.match(display, /EVENT_ID/, 'Storskjerm must support event-scoped links');
assert.match(cupPage, /claim_event_cup/, 'Digital cup page must use event-scoped claims');
assert.match(relay, /event_cup_id/, 'RFID relay must attach reads to an allocated event cup');
assert.match(relay, /recorded \(legacy mode\)/, 'RFID relay must preserve legacy behavior before the first configured event');

function assertInlineScriptsCompile(source, label) {
  const scripts = [...source.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map(match => match[1])
    .filter(script => script.trim());
  assert.ok(scripts.length > 0, `${label} must contain an inline script`);
  scripts.forEach((script, index) => {
    assert.doesNotThrow(() => new Function(script), `${label} inline script ${index + 1} must compile`);
  });
}

assertInlineScriptsCompile(config, 'Configuration page');
assertInlineScriptsCompile(display, 'Storskjerm');
assertInlineScriptsCompile(cupPage, 'Digital cup page');

console.log('Multi-event configuration regression checks passed.');
