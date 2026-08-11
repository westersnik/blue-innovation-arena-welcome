import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync(new URL('../storskjerm.html', import.meta.url), 'utf8');
const helperBlock = source.match(
  /const BATCH1_GIAI_START[\s\S]*?function cupNumberForEvent\(giai, epc\) \{[\s\S]*?\n  \}/,
);

assert.ok(helperBlock, 'Batch-aware cup-number helper must exist in storskjerm.html');
const { cupNumberForEvent } = new Function(
  `${helperBlock[0]}; return { cupNumberForEvent };`,
)();

// Batch 1 starts at cup #1 and keeps its original number space.
assert.equal(cupNumberForEvent('70735392043', '3415AFBC0C000000000007FB'), 1);
assert.equal(cupNumberForEvent('70735394096', '3415AFBC0C000000000001000'), 2054);

// Batch 2 is a separate event: it must start at cup #1, including the GIAI overlap.
assert.equal(cupNumberForEvent('70735394096', '3415AFBC0C00000000001000'), 1);
assert.equal(cupNumberForEvent('70735394097', '3415AFBC0C00000000001001'), 2);
assert.equal(cupNumberForEvent('70735394242', '3415AFBC0C00000000001092'), 147);
assert.equal(cupNumberForEvent('70735394595', '3415AFBC0C000000000011F3'), 500);

// Events outside the two event catalogues must not be rendered as a numbered cup.
assert.equal(cupNumberForEvent('70735391934', '3415AFBC0C0000000000012C'), null);

console.log('storskjerm batch-aware cup number tests passed');
