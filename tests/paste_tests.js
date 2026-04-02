// paste_tests.js — Node.js tests for paste handler logic
// Run with: node tests/paste_tests.js

// ── Minimal stubs for QField-only objects ────────────────────────────────────
const igletterMatrix = {
    A:{first:0,second:4},B:{first:1,second:4},C:{first:2,second:4},D:{first:3,second:4},E:{first:4,second:4},
    F:{first:0,second:3},G:{first:1,second:3},H:{first:2,second:3},J:{first:3,second:3},K:{first:4,second:3},
    L:{first:0,second:2},M:{first:1,second:2},N:{first:2,second:2},O:{first:3,second:2},P:{first:4,second:2},
    Q:{first:0,second:1},R:{first:1,second:1},S:{first:2,second:1},T:{first:3,second:1},U:{first:4,second:1},
    V:{first:0,second:0},W:{first:1,second:0},X:{first:2,second:0},Y:{first:3,second:0},Z:{first:4,second:0},
};

// Fixed to exactly match grids.qml. The old stub had systematic off-by-one
// errors in 'first' for most squares (SR onwards), included nonexistent TW,
// and was missing NF, NA, HT, HU — plus HP was completely wrong.
const ukletterMatrix = {
    SV:{first:0,second:0}, SW:{first:1,second:0}, SX:{first:2,second:0}, SY:{first:3,second:0}, SZ:{first:4,second:0},
    TV:{first:5,second:0},
    SR:{first:1,second:1}, SS:{first:2,second:1}, ST:{first:3,second:1}, SU:{first:4,second:1},
    TQ:{first:5,second:1}, TR:{first:6,second:1},
    SM:{first:1,second:2}, SN:{first:2,second:2}, SO:{first:3,second:2}, SP:{first:4,second:2},
    TL:{first:5,second:2}, TM:{first:6,second:2},
    SH:{first:2,second:3}, SJ:{first:3,second:3}, SK:{first:4,second:3},
    TF:{first:5,second:3}, TG:{first:6,second:3},
    SC:{first:2,second:4}, SD:{first:3,second:4}, SE:{first:4,second:4}, TA:{first:5,second:4},
    NW:{first:1,second:5}, NX:{first:2,second:5}, NY:{first:3,second:5}, NZ:{first:4,second:5}, OV:{first:5,second:5},
    NR:{first:1,second:6}, NS:{first:2,second:6}, NT:{first:3,second:6}, NU:{first:4,second:6},
    NL:{first:0,second:7}, NM:{first:1,second:7}, NN:{first:2,second:7}, NO:{first:3,second:7},
    NF:{first:0,second:8}, NG:{first:1,second:8}, NH:{first:2,second:8}, NJ:{first:3,second:8}, NK:{first:4,second:8},
    NA:{first:0,second:9}, NB:{first:1,second:9}, NC:{first:2,second:9}, ND:{first:3,second:9},
    HW:{first:1,second:10}, HX:{first:2,second:10}, HY:{first:3,second:10}, HZ:{first:4,second:10},
    HT:{first:3,second:11}, HU:{first:4,second:11},
    HP:{first:4,second:12},
};

// ── Functions extracted from main.qml / grids.qml ───────────────────────────

function padGridNumbers(numbers) {
    var len = numbers.length;
    if (len < 2 || len > 10 || len % 2 !== 0) return null;
    var half = len / 2;
    var e = numbers.substring(0, half);
    var n = numbers.substring(half);
    while (e.length < 5) e += '0';
    while (n.length < 5) n += '0';
    return e + ' ' + n;
}

function parseCoordPart(s) {
    s = s.trim();
    let hemi = '';
    let hLead = s.match(/^([NSEWnsew])\s*/);
    if (hLead) { hemi = hLead[1].toUpperCase(); s = s.substring(hLead[0].length).trim(); }
    let hTrail = s.match(/\s*([NSEWnsew])$/);
    if (hTrail) { hemi = hTrail[1].toUpperCase(); s = s.substring(0, s.length - hTrail[0].length).trim(); }
    let parts = s.split(/\s+/).map(Number);
    if (parts.length === 0 || parts.length > 3 || parts.some(isNaN)) return null;
    let decimal = Math.abs(parts[0]);
    if (parts.length >= 2) decimal += parts[1] / 60;
    if (parts.length >= 3) decimal += parts[2] / 3600;
    if (parts[0] < 0 || hemi === 'S' || hemi === 'W') decimal = -decimal;
    return decimal;
}

// Simulates handlePaste routing — returns a result object describing what was detected
function simulatePaste(clipboardText) {
    if (!clipboardText) return { route: 'empty' };
    let raw = clipboardText.trim();
    let compact = raw.replace(/\s+/g, '').substring(0, 200);

    // WKT
    let wktMatch = raw.match(/Point\s*(ZM|Z|M)?\s*\(\s*([-\d.]+)\s+([-\d.]+)(?:\s+([-\d.]+))?(?:\s+([-\d.]+))?\s*\)/i);
    if (wktMatch) {
        let wktType = (wktMatch[1] || '').toUpperCase();
        let wktX = parseFloat(wktMatch[2]), wktY = parseFloat(wktMatch[3]);
        let val3 = wktMatch[4] !== undefined ? parseFloat(wktMatch[4]) : NaN;
        let hasZ = (wktType === 'Z' || wktType === 'ZM') && !isNaN(val3);
        if (!isNaN(wktX) && !isNaN(wktY))
            return { route: 'wkt', x: wktX, y: wktY, type: wktType || 'POINT', hasZ, z: hasZ ? val3 : undefined };
    }

    // MGRS (stub — just check regex matches)
    let mgrsClean = raw.replace(/\s+/g, '').toUpperCase();
    if (/^\d{0,2}[A-Z]{3}\d{0,10}$/.test(mgrsClean) && mgrsClean.length >= 3)
        return { route: 'mgrs_candidate', value: mgrsClean };

    // Plus Code
    let olcTest = raw.trim().toUpperCase();
    if (/^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{0,}$/.test(olcTest) && olcTest.indexOf('+') === 8)
        return { route: 'pluscode', value: olcTest };

    // UK Grid
    if (/^[A-Z]{2}\d{2,10}$/i.test(compact) && compact.substring(2).length % 2 === 0) {
        let letters = compact.substring(0,2).toUpperCase();
        let padded = padGridNumbers(compact.substring(2));
        let entry = ukletterMatrix[letters];
        if (entry && padded) {
            let easting  = parseInt(padded.substring(0,5)) + entry.first  * 100000;
            let northing = parseInt(padded.substring(6))   + entry.second * 100000;
            return { route: 'uk_grid', display: `${letters} ${padded}`, easting, northing };
        }
        return { route: 'uk_grid_bad_letter', letters };
    }

    // Irish Grid
    if (/^[A-Z]\d{2,10}$/i.test(compact) && compact.substring(1).length % 2 === 0) {
        let letter = compact.substring(0,1).toUpperCase();
        let padded = padGridNumbers(compact.substring(1));
        let entry = igletterMatrix[letter];
        if (entry && padded) {
            let easting  = parseInt(padded.substring(0,5)) + entry.first  * 100000;
            let northing = parseInt(padded.substring(6))   + entry.second * 100000;
            return { route: 'ig_grid', display: `${letter} ${padded}`, easting, northing };
        }
        return { route: 'ig_grid_bad_letter', letter };
    }

    // Degree-based
    let norm = raw.replace(/°/g,' ').replace(/'/g,' ').replace(/"/g,' ').replace(/\s+/g,' ').trim();
    let hasDmsHemi = /[°'"NSEWnsew]/.test(raw);
    let commaIdx = norm.indexOf(',');
    if (commaIdx > 0) {
        let a = parseCoordPart(norm.substring(0, commaIdx));
        let b = parseCoordPart(norm.substring(commaIdx + 1));
        if (a !== null && b !== null) {
            let defIdx = (hasDmsHemi || (Math.abs(a) <= 90 && Math.abs(b) <= 180)) ? 0 : 4;
            return { route: 'decimal_pair', a, b, suggestedFormat: defIdx === 0 ? 'WGS84' : 'projected' };
        }
    }
    let sp = raw.trim().split(/\s+/);
    if (sp.length === 2) {
        let a = parseFloat(sp[0]), b = parseFloat(sp[1]);
        if (!isNaN(a) && !isNaN(b)) {
            let defIdx = (hasDmsHemi || (Math.abs(a) <= 90 && Math.abs(b) <= 180)) ? 0 : 4;
            return { route: 'space_pair', a, b, suggestedFormat: defIdx === 0 ? 'WGS84' : 'projected' };
        }
    }

    return { route: 'unrecognised' };
}

// ── Test harness ─────────────────────────────────────────────────────────────
let passed = 0, failed = 0;
function test(label, input, expectFn) {
    let result;
    try { result = simulatePaste(input); }
    catch(e) { result = { route: 'ERROR', err: e.message }; }
    let ok = expectFn(result);
    if (ok) { process.stdout.write(`  ✓ ${label}\n`); passed++; }
    else    { process.stdout.write(`  ✗ ${label}\n    input:  ${JSON.stringify(input)}\n    result: ${JSON.stringify(result)}\n`); failed++; }
}

// ── parseCoordPart unit tests ─────────────────────────────────────────────────
console.log('\n── parseCoordPart unit tests ──');
function testPCC(label, input, expected) {
    let result;
    try { result = parseCoordPart(input); } catch(e) { result = null; }
    let ok = expected === null
        ? result === null
        : result !== null && Math.abs(result - expected) < 0.0001;
    if (ok) { process.stdout.write(`  ✓ ${label}\n`); passed++; }
    else    { process.stdout.write(`  ✗ ${label}\n    input:  ${JSON.stringify(input)}\n    result: ${result} (expected ${expected})\n`); failed++; }
}
testPCC('plain decimal',              '53.3498',         53.3498);
testPCC('negative decimal',           '-6.2603',         -6.2603);
testPCC('positive with + sign',       '+53.3498',        53.3498);
testPCC('N prefix → positive',        'N53.3498',        53.3498);
testPCC('S prefix → negative',        'S53.3498',        -53.3498);
testPCC('W prefix → negative',        'W6.2603',         -6.2603);
testPCC('E prefix → positive',        'E6.2603',         6.2603);
testPCC('N suffix → positive',        '53.3498 N',       53.3498);
testPCC('S suffix → negative',        '53.3498 S',       -53.3498);
testPCC('W suffix → negative',        '6.2603 W',        -6.2603);
testPCC('E suffix → positive',        '6.2603 E',        6.2603);
testPCC('DDM',                        '53 20.988',       53 + 20.988/60);
testPCC('DMS',                        '53 20 59',        53 + 20/60 + 59/3600);
testPCC('DMS with N suffix',          '53 20 59 N',      53 + 20/60 + 59/3600);
testPCC('DMS with S suffix → neg',    '53 20 59 S',      -(53 + 20/60 + 59/3600));
testPCC('DMS fractional seconds',     '53 20 59.5',      53 + 20/60 + 59.5/3600);
testPCC('zero',                        '0',               0);
testPCC('negative with S suffix',     '-53.3498 S',      -53.3498); // sign+hemi both flip → stays neg
testPCC('4 parts → null',            '53 20 59 12',     null);
testPCC('empty string → 0 (not null)', '',                0);   // ''.split(/\s+/)→[''], Number('')→0
testPCC('letters only → null',        'abc',             null);
testPCC('NaN value → null',           'NaN',             null);

// ── padGridNumbers unit tests ─────────────────────────────────────────────────
console.log('\n── padGridNumbers ──');
function testPad(input, expected) {
    let result = padGridNumbers(input);
    let ok = result === expected;
    if (ok) { process.stdout.write(`  ✓ "${input}" → "${result}"\n`); passed++; }
    else    { process.stdout.write(`  ✗ "${input}" → "${result}" (expected "${expected}")\n`); failed++; }
}
testPad('5644445000',  '56444 45000');  // 10 digits — exact
testPad('56444450',    '56440 44500');  // 8 digits — right-pad each half
testPad('564445',      '56400 44500');  // 6 digits
testPad('5644',        '56000 44000');  // 4 digits
testPad('56',          '50000 60000');  // 2 digits — 1+1
testPad('0000000000',  '00000 00000');  // all zeros
testPad('9999999999',  '99999 99999');  // all nines
testPad('0102',        '01000 02000');  // leading zeros preserved
testPad('0000',        '00000 00000');  // leading zeros 4-digit
testPad('',            null);           // empty
testPad('1',           null);           // 1 digit (odd)
testPad('123',         null);           // 3 digits (odd)
testPad('12345',       null);           // 5 digits (odd)
testPad('1234567',     null);           // 7 digits (odd)
testPad('123456789',   null);           // 9 digits (odd)
testPad('12345678901', null);           // 11 digits (too long)
testPad('00',          '00000 00000');  // zeros 2-digit

// ── Irish Grid paste — all 25 valid letters ──────────────────────────────────
// Using 4-digit (2+2) format: "X 12 34" → padded "12000 34000"
// easting = 12000 + first*100000, northing = 34000 + second*100000
console.log('\n── Irish Grid — all 25 letters ──');
test('letter A {0,4}', 'A 12 34', r => r.route==='ig_grid' && r.easting===12000  && r.northing===434000);
test('letter B {1,4}', 'B 12 34', r => r.route==='ig_grid' && r.easting===112000 && r.northing===434000);
test('letter C {2,4}', 'C 12 34', r => r.route==='ig_grid' && r.easting===212000 && r.northing===434000);
test('letter D {3,4}', 'D 12 34', r => r.route==='ig_grid' && r.easting===312000 && r.northing===434000);
test('letter E {4,4}', 'E 12 34', r => r.route==='ig_grid' && r.easting===412000 && r.northing===434000);
test('letter F {0,3}', 'F 12 34', r => r.route==='ig_grid' && r.easting===12000  && r.northing===334000);
test('letter G {1,3}', 'G 12 34', r => r.route==='ig_grid' && r.easting===112000 && r.northing===334000);
test('letter H {2,3}', 'H 12 34', r => r.route==='ig_grid' && r.easting===212000 && r.northing===334000);
test('letter J {3,3}', 'J 12 34', r => r.route==='ig_grid' && r.easting===312000 && r.northing===334000);
test('letter K {4,3}', 'K 12 34', r => r.route==='ig_grid' && r.easting===412000 && r.northing===334000);
test('letter L {0,2}', 'L 12 34', r => r.route==='ig_grid' && r.easting===12000  && r.northing===234000);
test('letter M {1,2}', 'M 12 34', r => r.route==='ig_grid' && r.easting===112000 && r.northing===234000);
test('letter N {2,2}', 'N 12 34', r => r.route==='ig_grid' && r.easting===212000 && r.northing===234000);
test('letter O {3,2}', 'O 12 34', r => r.route==='ig_grid' && r.easting===312000 && r.northing===234000);
test('letter P {4,2}', 'P 12 34', r => r.route==='ig_grid' && r.easting===412000 && r.northing===234000);
test('letter Q {0,1}', 'Q 12 34', r => r.route==='ig_grid' && r.easting===12000  && r.northing===134000);
test('letter R {1,1}', 'R 12 34', r => r.route==='ig_grid' && r.easting===112000 && r.northing===134000);
test('letter S {2,1}', 'S 12 34', r => r.route==='ig_grid' && r.easting===212000 && r.northing===134000);
test('letter T {3,1}', 'T 12 34', r => r.route==='ig_grid' && r.easting===312000 && r.northing===134000);
test('letter U {4,1}', 'U 12 34', r => r.route==='ig_grid' && r.easting===412000 && r.northing===134000);
test('letter V {0,0}', 'V 12 34', r => r.route==='ig_grid' && r.easting===12000  && r.northing===34000);
test('letter W {1,0}', 'W 12 34', r => r.route==='ig_grid' && r.easting===112000 && r.northing===34000);
test('letter X {2,0}', 'X 12 34', r => r.route==='ig_grid' && r.easting===212000 && r.northing===34000);
test('letter Y {3,0}', 'Y 12 34', r => r.route==='ig_grid' && r.easting===312000 && r.northing===34000);
test('letter Z {4,0}', 'Z 12 34', r => r.route==='ig_grid' && r.easting===412000 && r.northing===34000);
test('letter I → reject',   'I 12 34', r => r.route==='ig_grid_bad_letter');
test('lowercase all letters', 'h 12 34', r => r.route==='ig_grid');

// ── Irish Grid paste — all precision levels ──────────────────────────────────
// H = {first:2, second:3} → easting base 200000, northing base 300000
console.log('\n── Irish Grid — precision levels ──');
test('10-digit no spaces',      'H5432189797',    r => r.route==='ig_grid' && r.easting===254321 && r.northing===389797);
test('10-digit with spaces',    'H 54321 89797',  r => r.route==='ig_grid' && r.easting===254321 && r.northing===389797);
test('8-digit (4+4)',           'H 5432 8979',    r => r.route==='ig_grid' && r.easting===254320 && r.northing===389790);
test('6-digit (3+3)',           'H 543 897',      r => r.route==='ig_grid' && r.easting===254300 && r.northing===389700);
test('6-digit no spaces',       'H543897',        r => r.route==='ig_grid' && r.easting===254300 && r.northing===389700);
test('4-digit (2+2)',           'H 54 89',        r => r.route==='ig_grid' && r.easting===254000 && r.northing===389000);
test('2-digit (1+1)',           'H 5 8',          r => r.route==='ig_grid' && r.easting===250000 && r.northing===380000);
test('letter V (SW corner)',    'V 00000 00000',  r => r.route==='ig_grid' && r.easting===0 && r.northing===0);
test('letter Z (NE corner)',    'Z 99999 99999',  r => r.route==='ig_grid' && r.easting===499999 && r.northing===99999);
test('O ref (Dublin area)',     'O 15930 34300',  r => r.route==='ig_grid' && r.easting===315930 && r.northing===234300);
test('leading zeros in digits', 'H 00123 00456',  r => r.route==='ig_grid' && r.easting===200123 && r.northing===300456);
test('leading zeros 4-digit',   'H 01 02',        r => r.route==='ig_grid' && r.easting===201000 && r.northing===302000);
test('all zeros',               'H 00000 00000',  r => r.route==='ig_grid' && r.easting===200000 && r.northing===300000);

// Ambiguous — N, S, E, W, V are valid IG letters; grid check must win
test('N letter (not NSEW hemi)', 'N 12345 67890', r => r.route==='ig_grid' && r.easting===212345 && r.northing===267890);
test('S letter (not NSEW hemi)', 'S 12345 67890', r => r.route==='ig_grid' && r.easting===212345 && r.northing===167890);
test('E letter (not NSEW hemi)', 'E 12345 67890', r => r.route==='ig_grid' && r.easting===412345 && r.northing===467890);
test('W letter (not NSEW hemi)', 'W 12345 67890', r => r.route==='ig_grid' && r.easting===112345 && r.northing===67890);
test('V letter (not SW corner)', 'V 12345 67890', r => r.route==='ig_grid' && r.easting===12345  && r.northing===67890);

// Reject cases
test('odd 5 digits → reject',   'H12345',         r => r.route!=='ig_grid');
test('odd 7 digits → reject',   'H1234567',       r => r.route!=='ig_grid');
test('odd 9 digits → reject',   'H123456789',     r => r.route!=='ig_grid');
test('11 digits → reject',      'H12345678901',   r => r.route!=='ig_grid');
test('invalid letter I',        'I 12345 67890',  r => r.route==='ig_grid_bad_letter');

// ── UK Grid paste — fixed matrix, corrected expected values ──────────────────
// NS = {first:2, second:6} → easting base 200000, northing base 600000
// (Previous stub had NS as {first:1,second:6} — easting assertions were all wrong)
console.log('\n── UK Grid — precision levels (NS) ──');
test('10-digit no spaces',      'NS4514072887',   r => r.route==='uk_grid' && r.easting===245140 && r.northing===672887);
test('10-digit with spaces',    'NS 45140 72887', r => r.route==='uk_grid' && r.easting===245140 && r.northing===672887);
test('8-digit (4+4)',           'NS 4514 7288',   r => r.route==='uk_grid' && r.easting===245140 && r.northing===672880);
test('6-digit (3+3)',           'NS 451 728',     r => r.route==='uk_grid' && r.easting===245100 && r.northing===672800);
test('6-digit no spaces',       'NS451728',       r => r.route==='uk_grid' && r.easting===245100 && r.northing===672800);
test('4-digit (2+2)',           'NS 45 72',       r => r.route==='uk_grid' && r.easting===245000 && r.northing===672000);
test('2-digit (1+1)',           'NS 4 7',         r => r.route==='uk_grid' && r.easting===240000 && r.northing===670000);
test('lowercase letters',       'ns 45140 72887', r => r.route==='uk_grid');
test('all zeros',               'NS 00000 00000', r => r.route==='uk_grid' && r.easting===200000 && r.northing===600000);

console.log('\n── UK Grid — other squares ──');
// TQ = {first:5, second:1} — central London area
test('TQ (London)',             'TQ 30000 80000', r => r.route==='uk_grid' && r.easting===530000 && r.northing===180000);
// SP = {first:4, second:2} — Midlands
test('SP (Birmingham)',         'SP 50000 20000', r => r.route==='uk_grid' && r.easting===450000 && r.northing===220000);
// SE = {first:4, second:4} — Yorkshire
test('SE (Sheffield)',          'SE 35200 87500', r => r.route==='uk_grid' && r.easting===435200 && r.northing===487500);
// NN = {first:2, second:7} — Scottish Highlands
test('NN (Ben Nevis area)',     'NN 16600 77200', r => r.route==='uk_grid' && r.easting===216600 && r.northing===777200);
// HY = {first:3, second:10} — Orkney
test('HY (Orkney)',             'HY 51700 08000', r => r.route==='uk_grid' && r.easting===351700 && r.northing===1008000);
// HU = {first:4, second:11} — Shetland
test('HU (Shetland)',           'HU 40000 10000', r => r.route==='uk_grid' && r.easting===440000 && r.northing===1110000);
// HP = {first:4, second:12} — Unst (northernmost)
test('HP (Unst)',               'HP 60000 10000', r => r.route==='uk_grid' && r.easting===460000 && r.northing===1210000);
// NF = {first:0, second:8} — Outer Hebrides
test('NF (Outer Hebrides)',     'NF 72800 32800', r => r.route==='uk_grid' && r.easting===72800  && r.northing===832800);
// NA = {first:0, second:9} — Cape Wrath area
test('NA (Cape Wrath)',         'NA 12000 10000', r => r.route==='uk_grid' && r.easting===12000  && r.northing===910000);
// HT = {first:3, second:11}
test('HT',                     'HT 00000 00000', r => r.route==='uk_grid' && r.easting===300000 && r.northing===1100000);
// SV = {first:0, second:0} — SW corner of UK grid (Scilly Isles)
test('SV (SW corner)',          'SV 00000 00000', r => r.route==='uk_grid' && r.easting===0 && r.northing===0);
// SH = {first:2, second:3} — Snowdonia
test('SH (Snowdonia)',          'SH 60000 55000', r => r.route==='uk_grid' && r.easting===260000 && r.northing===355000);

// Reject cases
test('odd 5 digits → reject',   'NS12345',        r => r.route!=='uk_grid');
test('odd 7 digits → reject',   'NS1234567',      r => r.route!=='uk_grid');
test('11 digits → reject',      'NS12345678901',  r => r.route!=='uk_grid');
test('invalid square ZZ',       'ZZ 12345 67890', r => r.route==='uk_grid_bad_letter');
test('invalid square AA',       'AA 12345 67890', r => r.route==='uk_grid_bad_letter');
test('nonexistent TW',          'TW 12345 67890', r => r.route==='uk_grid_bad_letter'); // TW is NOT in OSGB

// ── Grid ref whitespace variants ──────────────────────────────────────────────
console.log('\n── Grid ref whitespace variants ──');
test('tab between letter and digits (IG)', 'H\t54321\t89797',    r => r.route==='ig_grid' && r.easting===254321);
test('double space (IG)',                   'H  54321  89797',    r => r.route==='ig_grid' && r.easting===254321);
test('leading/trailing whitespace (IG)',    '  H 54321 89797  ', r => r.route==='ig_grid' && r.easting===254321);
test('tab between letters and digits (UK)', 'NS\t45140\t72887',  r => r.route==='uk_grid' && r.easting===245140);
test('double space (UK)',                   'NS  45140  72887',  r => r.route==='uk_grid' && r.easting===245140);
test('newline mid-ref (IG)',                'H 54321\n89797',    r => r.route==='ig_grid' && r.easting===254321);

// ── Grid ref typos and near-misses ───────────────────────────────────────────
console.log('\n── Grid ref typos / near-misses ──');
// Extra letter prefix → UK path then bad letter
test('extra letter: HH prefix',     'HH 54321 89797',  r => r.route==='uk_grid_bad_letter');
test('extra letter: ZZ prefix',     'ZZ 12345 67890',  r => r.route==='uk_grid_bad_letter');
// Digit where letter expected
test('digit-then-letter: 1H...',    '1H 54321 89797',  r => r.route!=='ig_grid' && r.route!=='uk_grid');
// Letter embedded in digits
test('letter in digits: H 543A1 89797', 'H 543A1 89797', r => r.route!=='ig_grid');
// Hyphen separator
test('hyphen separator (IG)',       'H-54321-89797',   r => r.route!=='ig_grid');
test('hyphen separator (UK)',       'NS-45140-72887',  r => r.route!=='uk_grid');
// Dot separator
test('dot separator (UK)',          'NS.45140.72887',  r => r.route!=='uk_grid');
// Slash separator
test('slash separator (IG)',        'H/54321/89797',   r => r.route!=='ig_grid');
// Trailing punctuation
test('trailing ! (UK)',             'NS 45140 72887!', r => r.route!=='uk_grid');
// Odd digit counts
test('3 digits after letter',       'H123',            r => r.route!=='ig_grid');
test('single letter only (H)',      'H',               r => r.route==='unrecognised');
test('two letters only (NS)',       'NS',              r => r.route==='unrecognised');
// Extra space inside digit groups — whitespace is stripped so this DOES parse
test('extra space inside digits',   'H 543 21 89797',  r => r.route==='ig_grid'); // compact = H5432189797
// Underscore separator
test('underscore separator',        'H_54321_89797',   r => r.route!=='ig_grid');
// Correct format but letter not in matrix
test('IG letter I → bad_letter',    'I 12345 67890',   r => r.route==='ig_grid_bad_letter');

// ── WGS84 decimal degrees ─────────────────────────────────────────────────────
console.log('\n── WGS84 decimal degrees ──');
test('simple lat,lon',              '53.3498, -6.2603',    r => r.route==='decimal_pair' && Math.abs(r.a-53.3498)<0.0001 && Math.abs(r.b-(-6.2603))<0.0001);
test('positive lon',                '1.2345, 36.8219',     r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('both negative',               '-33.8688, -70.6693',  r => r.route==='decimal_pair' && r.a < 0 && r.b < 0);
test('N prefix',                    'N53.3498, W6.2603',   r => r.route==='decimal_pair' && Math.abs(r.a-53.3498)<0.0001 && Math.abs(r.b-(-6.2603))<0.0001);
test('S prefix → negative',        'S53.3498, W6.2603',   r => r.route==='decimal_pair' && r.a < 0 && r.b < 0);
test('trailing NSEW',               '53.3498N, 6.2603W',   r => r.route==='decimal_pair' && r.b < 0);
test('S+W trailing',                '53.3498S, 6.2603W',   r => r.route==='decimal_pair' && r.a < 0 && r.b < 0);
test('explicit E east',             '53.3498N, 6.2603E',   r => r.route==='decimal_pair' && r.a > 0 && r.b > 0);
test('space-separated pair',        '53.3498 -6.2603',     r => r.route==='space_pair');
test('space pair both pos',         '1.234 36.822',        r => r.route==='space_pair' && r.suggestedFormat==='WGS84');
test('projected large coords',      '313621, 234156',      r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('projected space pair',        '453561 248092',       r => r.route==='space_pair' && r.suggestedFormat==='projected');
test('lat exactly 90',              '90, 0',               r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('lat exactly -90',             '-90, 0',              r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('lon exactly 180',             '0, 180',              r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('lat 90.1 → projected',        '90.1, 10',            r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('lon 180.1 → projected',       '0, 180.1',            r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('0,0 (null island)',            '0, 0',                r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('extra spaces around comma',    '  53.3498 ,  -6.2603  ', r => r.route==='decimal_pair');
test('tab as space pair sep',        '53.3498\t-6.2603',   r => r.route==='space_pair');
test('+ prefix is valid',            '+53.3498, +6.2603',  r => r.route==='decimal_pair' && r.a > 0 && r.b > 0);
test('many decimal places',          '53.349812345678, -6.260398765432', r => r.route==='decimal_pair');

// ── Hemisphere / sign conflict edge cases ─────────────────────────────────────
console.log('\n── Hemisphere / sign conflicts ──');
// -value + S suffix: negation applied once (condition is OR not sequential ifs)
test('-53.3498 S → still negative',  '-53.3498 S, 6.2603',  r => r.route==='decimal_pair' && r.a < 0);
// Positive value with S suffix → negative
test('53.3498 S → negative',         '53.3498 S, 6.2603',   r => r.route==='decimal_pair' && r.a < 0);
// N suffix on negative number → negative (parts[0]<0 flips, N doesn't)
test('-53.3498 N → negative',        '-53.3498 N, 6.2603',  r => r.route==='decimal_pair' && r.a < 0);
// W on positive longitude
test('6.2603 W → negative lon',      '53.3498, 6.2603 W',   r => r.route==='decimal_pair' && r.b < 0);
// E on negative longitude (signs should resolve)
test('-6.2603 E → negative lon',     '53.3498, -6.2603 E',  r => r.route==='decimal_pair' && r.b < 0);

// ── DDM / DMS ─────────────────────────────────────────────────────────────────
console.log('\n── DDM / DMS ──');
test('DDM with NSEW',            "53° 20.988' N, 6° 15.619' W",   r => r.route==='decimal_pair' && Math.abs(r.a-53.3498)<0.001 && r.b < 0);
test('DMS with NSEW',            '53° 20\' 59" N, 6° 15\' 37" W', r => r.route==='decimal_pair' && r.a > 53 && r.b < 0);
test('DMS minus sign',           '-53° 20\' 59", -6° 15\' 37"',   r => r.route==='decimal_pair' && r.a < 0 && r.b < 0);
test('DDM no hemisphere',        "53° 20.988', -6° 15.619'",       r => r.route==='decimal_pair');
test('DMS fractional seconds',   '53° 20\' 59.5" N, 6° 15\' 37.5" W', r => r.route==='decimal_pair' && r.a > 53 && r.b < 0);
test('S hemisphere DMS',         '6° 25.0\' S, 45° 10.0\' W',     r => r.route==='decimal_pair' && r.a < 0 && r.b < 0);
test('DDM integer minutes',      '53° 20\' N, 6° 15\' W',         r => r.route==='decimal_pair');
test('DMS no symbols (spaces)',  '53 20 59, 6 15 37',              r => r.route==='decimal_pair');
// DMS without comma between lat/lon — known gap, no comma → unrecognised
test('DMS no comma between → unrecog', '53° 20\' 59" N 6° 15\' 37" W', r => r.route==='unrecognised');
test('DDM no comma between → unrecog', "53° 20.988' N 6° 15.619' W",   r => r.route==='unrecognised');
// Garmin-style (N53°...) no comma — also unrecognised
test('Garmin N53.3498 W006.2603 → unrecog', 'N53.3498 W006.2603', r => r.route==='unrecognised');

// ── WKT ───────────────────────────────────────────────────────────────────────
console.log('\n── WKT ──');
test('POINT 2D',              'POINT (84092.667 53131.478)',       r => r.route==='wkt' && r.type==='POINT' && !r.hasZ);
test('POINT Z',               'POINT Z (1 1 5)',                   r => r.route==='wkt' && r.type==='Z' && r.hasZ && r.z===5);
test('POINT M (no Z)',        'POINT M (1 1 80)',                  r => r.route==='wkt' && r.type==='M' && !r.hasZ);
test('POINT ZM',              'POINT ZM (1 1 5 60)',              r => r.route==='wkt' && r.type==='ZM' && r.hasZ && r.z===5);
test('lowercase point',       'point (100 200)',                   r => r.route==='wkt');
test('mixed case pOiNt Z',    'pOiNt Z (1 2 3)',                  r => r.route==='wkt' && r.hasZ);
test('negative coords',       'POINT (-6.260 53.349)',             r => r.route==='wkt' && r.x===-6.260 && r.y===53.349);
test('negative Z',            'POINT Z (100 200 -50)',             r => r.route==='wkt' && r.hasZ && r.z===-50);
test('zero Z',                'POINT Z (100 200 0)',               r => r.route==='wkt' && r.hasZ && r.z===0);
test('POINT Z only 2 nums → no Z', 'POINT Z (1 2)',              r => r.route==='wkt' && r.type==='Z' && !r.hasZ);
test('extra whitespace inside', 'POINT (  1.234   5.678  )',       r => r.route==='wkt' && Math.abs(r.x-1.234)<0.001);
test('high precision coords', 'POINT (84092.66714064161351416 53131.47802533095091349)', r => r.route==='wkt' && Math.abs(r.x-84092.667)<0.01);
test('full QField feature dump', 'Geometry:: Point (84092.66714064161351416 53131.47802533095091349)\nfid: 15500\nSurvey: CWEF',
                                                                    r => r.route==='wkt' && Math.abs(r.x-84092.667)<0.01);
test('WKT embedded in text',  'Location: POINT (53.3498 -6.2603) attr: foo', r => r.route==='wkt');
test('Geometry:: prefix',     'Geometry:: Point (314193 234087)', r => r.route==='wkt');
test('POINT ZM decimal',      'POINT ZM (1.5 2.5 3.5 4.5)',      r => r.route==='wkt' && r.hasZ && Math.abs(r.z-3.5)<0.001);
test('LINESTRING → reject',   'LINESTRING (0 0, 1 1)',            r => r.route!=='wkt');
test('POLYGON → reject',      'POLYGON ((0 0, 1 0, 1 1, 0 0))',  r => r.route!=='wkt');
test('POINT missing paren',   'POINT 1 2',                        r => r.route!=='wkt');
test('POINT empty parens',    'POINT ()',                          r => r.route!=='wkt');
test('POINT letters',         'POINT (abc def)',                   r => r.route!=='wkt');
test('POINT one number',      'POINT (123)',                       r => r.route!=='wkt');

// ── Plus Code ─────────────────────────────────────────────────────────────────
console.log('\n── Plus Code ──');
test('valid 10-char code',    '9C5P37C3+45',   r => r.route==='pluscode');
test('valid 11-char code',    '9C5P37C3+45J',  r => r.route==='pluscode');
test('uppercase only',        '9C5P37C3+45J',  r => r.route==='pluscode');
test('no plus → unrecog',     '9C5P37C345J',   r => r.route!=='pluscode');
test('plus at wrong pos',     '9C5P+37C345J',  r => r.route!=='pluscode');

// ── Coordinate separator variations ──────────────────────────────────────────
console.log('\n── Coordinate separator variations ──');
// Semicolon — space_pair: parseFloat('53.3498;')=53.3498 (lenient, stops at ';')
test('semicolon sep → space_pair', '53.3498; -6.2603', r => r.route==='space_pair');
// Slash — unrecog
test('slash sep',              '53.3498/-6.2603',    r => r.route==='unrecognised');
// Slash with spaces — sp length 3 → unrecog
test('slash with spaces',      '53.3498 / -6.2603',  r => r.route==='unrecognised');
// Pipe
test('pipe sep',               '53.3498|-6.2603',    r => r.route==='unrecognised');
// Comma+space is standard
test('comma+space (standard)', '53.3498, -6.2603',   r => r.route==='decimal_pair');
// No separator at all — two numbers jammed together
test('no sep: 53.3498-6.2603', '53.3498-6.2603',     r => r.route==='unrecognised');

// ── European comma-as-decimal separator ───────────────────────────────────────
console.log('\n── European decimal separator ──');
// '53,3498' → commaIdx at 2, a=53, b=3498 → decimal_pair (projected, false positive)
test('EU decimal single coord', '53,3498',              r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
// '53,3498 -6,2603' → space_pair: parseFloat('53,3498')=53, parseFloat('-6,2603')=-6 (truncate at comma)
// False positive: returns space_pair a=53, b=-6 — coordinates are wrong but not a crash
test('EU decimal pair → space_pair (false pos)', '53,3498 -6,2603', r => r.route==='space_pair' && r.a===53 && r.b===-6);
// Both with comma decimal and comma separator → commaIdx at first comma
test('mixed EU format',         '53,3498, 6,2603',     r => r.route!=='unrecognised'); // partial parse, not crash

// ── Three or more values ──────────────────────────────────────────────────────
console.log('\n── Three+ values ──');
// 3 comma-sep values → b parsing fails on '100' after -6.2603,
test('3 CSV values → unrecog', '53.3498, -6.2603, 100',   r => r.route==='unrecognised');
// 4 space-sep values → sp.length=4, not 2 → unrecog
test('4 space values → unrecog', '53.3498 -6.2603 100 200', r => r.route==='unrecognised');
// 3 space values → unrecog
test('3 space values → unrecog', '53.3498 -6.2603 100',    r => r.route==='unrecognised');

// ── Accidental / garbage inputs ───────────────────────────────────────────────
console.log('\n── Accidental / garbage inputs ──');
test('empty string',             '',                    r => r.route==='empty');
test('null',                     null,                  r => r.route==='empty');
test('spaces only',              '   ',                 r => r.route==='unrecognised');
test('single number',            '53.3498',             r => r.route==='unrecognised');
test('single integer',           '42',                  r => r.route==='unrecognised');
test('single letter H',          'H',                   r => r.route==='unrecognised');
test('two letters NS',           'NS',                  r => r.route==='unrecognised');
test('comma only',               ',',                   r => r.route==='unrecognised');
test('NaN pair',                 'abc, def',            r => r.route==='unrecognised');
test('plain text sentence',      'Adrigole River survey point', r => r.route==='unrecognised');
test('URL with coords',          'https://maps.google.com/?q=53.34,-6.26', r => r.route==='unrecognised');
test('what3words',               '///tables.tread.blush', r => r.route==='unrecognised');
test('postcode D1 5XR',          'D1 5XR',              r => r.route==='unrecognised');
test('UK postcode SW1A 2AA',     'SW1A 2AA',            r => r.route==='unrecognised'); // SW → UK grid → bad letter
test('very long string',         'A'.repeat(500),       r => r.route!=='ig_grid');
test('all zeros pair',           '0, 0',                r => r.route==='decimal_pair');
test('negative pair',            '-90, -180',           r => r.route==='decimal_pair');
test('Infinity string → decimal_pair', 'Infinity, 53.3', r => r.route==='decimal_pair'); // JS Infinity is not NaN; a=Infinity (serialises as null in JSON)
test('NaN as text',              'NaN, NaN',            r => r.route==='unrecognised');
test('just a dot',               '.',                   r => r.route==='unrecognised');
test('just a minus',             '-',                   r => r.route==='unrecognised');
test('emoji',                    '📍 53.3498, -6.2603', r => r.route!=='ig_grid'); // might parse as decimal_pair or unrecog
test('newline only',             '\n',                  r => r.route==='unrecognised');

// ── Punctuation and copy-paste artefacts ──────────────────────────────────────
console.log('\n── Punctuation / copy-paste artefacts ──');
// BOM (U+FEFF) — JS trim() removes it in ES5+
test('BOM prefix',               '\uFEFF53.3498, -6.2603',  r => r.route==='decimal_pair');
// Non-breaking space (U+00A0) — matched by \s in JS regex
test('NBSP as separator',        '53.3498,\u00A0-6.2603',   r => r.route==='decimal_pair');
// Zero-width space (U+200B) — NOT matched by JS \s or trim() in V8
test('zero-width space',         '53.3498,\u200B-6.2603',   r => r.route==='decimal_pair' || r.route==='unrecognised');
// Brackets around coords — '(' is not stripped; parseCoordPart('(53.3498')→Number('(53.3498')=NaN→unrecog
test('brackets around coords → unrecog', '(53.3498, -6.2603)', r => r.route==='unrecognised');
test('square brackets',          '[53.3498, -6.2603]',      r => r.route==='unrecognised');
// Quotes
test('quoted coordinates → parses', '"53.3498, -6.2603"', r => r.route==='decimal_pair'); // leading " ignored by Number() in some contexts; actual behaviour is parse succeeds
// Degree symbol alone
test('degree symbols only',      '° °',                     r => r.route==='unrecognised');
// Repeated commas
test('double comma → space_pair', '53.3498,, -6.2603',      r => r.route==='space_pair'); // comma path: b=parseCoordPart(', -6.2603')→NaN; space path: parseFloat('53.3498,,')=53.3498
// Trailing comma
test('trailing comma → space_pair', '53.3498, -6.2603,',   r => r.route==='space_pair'); // comma path: b=parseCoordPart('-6.2603,')→Number('-6.2603,')=NaN; space: parseFloat('-6.2603,')=−6.2603
// Leading comma
test('leading comma',            ',53.3498, -6.2603',       r => r.route==='unrecognised'); // commaIdx=0, not >0

// ── Real-world clipboard formats ──────────────────────────────────────────────
console.log('\n── Real-world clipboard formats ──');
// Google Maps share URL — unrecog (URL contains letters, no valid coord structure)
test('Google Maps URL',          'https://maps.google.com/maps?q=53.3498,-6.2603', r => r.route==='unrecognised');
// Google Maps coordinate share (just the coords)
test('Google Maps coords',       '53.3498, -6.2603',        r => r.route==='decimal_pair');
// OS Maps 10-digit NGR
test('OS NGR 10-digit',          'NS 45140 72887',          r => r.route==='uk_grid' && r.easting===245140);
// QGIS feature info
test('QGIS Point()',             'Point (314193 234087)',    r => r.route==='wkt');
// GPS easting/northing pair (large projected)
test('projected pair large',     '314193, 234087',          r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
// Garmin export without comma (no comma → unrecog)
test('Garmin N/W no comma',      'N53.349800 W006.260300',  r => r.route==='unrecognised');
// ISO 6709 style (sign always)
test('ISO 6709 style',           '+53.3498, -006.2603',     r => r.route==='decimal_pair' && r.a > 0 && r.b < 0);
// OGC WKT from PostGIS/QGIS
test('WKT from PostGIS',         'POINT(314193.456 234087.123)', r => r.route==='wkt' && Math.abs(r.x-314193.456)<0.01);
// Multiline QField paste
test('multiline with WKT',       'POINT Z (84092 53131 15)\nfid: 12\nSurvey: test', r => r.route==='wkt' && r.hasZ && r.z===15);
// OS grid ref with extra label text
test('grid ref with label text', 'Grid: NS 45140 72887',    r => r.route==='unrecognised'); // "Grid:" breaks compact
// Two numbers on separate lines
test('lat and lon on separate lines', '53.3498\n-6.2603',   r => r.route==='space_pair'); // split by \s+ treats \n as whitespace

// ── Edge / boundary values ────────────────────────────────────────────────────
console.log('\n── Boundary / edge values ──');
test('north pole',               '90, 0',                   r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('south pole',               '-90, 0',                  r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('antimeridian E',           '0, 180',                  r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('antimeridian W',           '0, -180',                 r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('just over antimeridian',   '0, 180.001',              r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('very small decimal',       '0.000001, 0.000001',      r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('very large projected',     '999999, 9999999',         r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('Irish grid NE corner Z',   'Z 99999 99999',           r => r.route==='ig_grid' && r.easting===499999 && r.northing===99999);
test('Irish grid SW corner V',   'V 00000 00000',           r => r.route==='ig_grid' && r.easting===0 && r.northing===0);

// ── Summary ───────────────────────────────────────────────────────────────────
console.log(`\n── Results: ${passed} passed, ${failed} failed ──\n`);
if (failed > 0) process.exit(1);
