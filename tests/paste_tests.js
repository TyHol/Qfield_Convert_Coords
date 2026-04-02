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
const ukletterMatrix = {
    SV:{first:0,second:0},SW:{first:1,second:0},SX:{first:2,second:0},SY:{first:3,second:0},SZ:{first:4,second:0},
    TV:{first:5,second:0},TW:{first:6,second:0},
    SR:{first:0,second:1},SS:{first:1,second:1},ST:{first:2,second:1},SU:{first:3,second:1},
    TQ:{first:4,second:1},TR:{first:5,second:1},
    SM:{first:0,second:2},SN:{first:1,second:2},SO:{first:2,second:2},SP:{first:3,second:2},
    TL:{first:4,second:2},TM:{first:5,second:2},
    SH:{first:0,second:3},SJ:{first:1,second:3},SK:{first:2,second:3},
    TF:{first:3,second:3},TG:{first:4,second:3},
    SC:{first:0,second:4},SD:{first:1,second:4},SE:{first:2,second:4},TA:{first:3,second:4},
    NW:{first:0,second:5},NX:{first:1,second:5},NY:{first:2,second:5},NZ:{first:3,second:5},OV:{first:4,second:5},
    NR:{first:0,second:6},NS:{first:1,second:6},NT:{first:2,second:6},NU:{first:3,second:6},
    NL:{first:0,second:7},NM:{first:1,second:7},NN:{first:2,second:7},NO:{first:3,second:7},
    NG:{first:0,second:8},NH:{first:1,second:8},NJ:{first:2,second:8},NK:{first:3,second:8},
    NB:{first:0,second:9},NC:{first:1,second:9},ND:{first:2,second:9},
    HW:{first:0,second:10},HX:{first:1,second:10},HY:{first:2,second:10},HZ:{first:3,second:10},
    HP:{first:0,second:11},
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
    // (isFull stub — check basic structure)
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

// ── padGridNumbers unit tests ─────────────────────────────────────────────────
console.log('\n── padGridNumbers ──');
function testPad(input, expected) {
    let result = padGridNumbers(input);
    let ok = result === expected;
    if (ok) { process.stdout.write(`  ✓ "${input}" → "${result}"\n`); passed++; }
    else    { process.stdout.write(`  ✗ "${input}" → "${result}" (expected "${expected}")\n`); failed++; }
}
testPad('5644445000',  '56444 45000');  // 10 digits
testPad('56444450',    '56440 44500');  // 8 digits (4+4 padded)
testPad('564445',      '56400 44500');  // 6 digits (3+3 padded)
testPad('5644',        '56000 44000');  // 4 digits (2+2 padded)
testPad('56',          '50000 60000');  // 2 digits (1+1 padded)
testPad('0000000000',  '00000 00000');  // all zeros
testPad('9999999999',  '99999 99999');  // all nines
testPad('',            null);           // empty
testPad('1',           null);           // 1 digit (odd)
testPad('123',         null);           // 3 digits (odd)
testPad('12345',       null);           // 5 digits (odd)
testPad('1234567',     null);           // 7 digits (odd)
testPad('123456789',   null);           // 9 digits (odd)
testPad('12345678901', null);           // 11 digits (too long)

// ── Irish Grid paste ─────────────────────────────────────────────────────────
console.log('\n── Irish Grid paste ──');
// H = {first:2, second:3} → easting base 200000, northing base 300000
test('10-digit no spaces',      'H5432189797',    r => r.route==='ig_grid' && r.easting===254321 && r.northing===389797);
test('10-digit with spaces',    'H 54321 89797',  r => r.route==='ig_grid' && r.easting===254321 && r.northing===389797);
test('8-digit (4+4)',           'H 5432 8979',    r => r.route==='ig_grid' && r.easting===254320 && r.northing===389790);
test('6-digit (3+3)',           'H 543 897',      r => r.route==='ig_grid' && r.easting===254300 && r.northing===389700);
test('6-digit no spaces',       'H543897',        r => r.route==='ig_grid' && r.easting===254300 && r.northing===389700);
test('4-digit (2+2)',           'H 54 89',        r => r.route==='ig_grid' && r.easting===254000 && r.northing===389000);
test('2-digit (1+1)',           'H 5 8',          r => r.route==='ig_grid' && r.easting===250000 && r.northing===380000);
test('lowercase letter',        'h 54321 89797',  r => r.route==='ig_grid');
test('letter V (SW corner)',    'V 00000 00000',  r => r.route==='ig_grid' && r.easting===0 && r.northing===0);
// Z = {first:4, second:0} → northing base 0
test('letter Z (NE corner)',    'Z 99999 99999',  r => r.route==='ig_grid' && r.easting===499999 && r.northing===99999);
// O = {first:3, second:2} → easting base 300000, northing base 200000
test('O ref (Dublin area)',     'O 15930 34300',  r => r.route==='ig_grid' && r.easting===315930 && r.northing===234300);
test('odd 5 digits → reject',   'H12345',         r => r.route!=='ig_grid');
test('odd 7 digits → reject',   'H1234567',       r => r.route!=='ig_grid');
test('odd 9 digits → reject',   'H123456789',     r => r.route!=='ig_grid');
test('11 digits → reject',      'H12345678901',   r => r.route!=='ig_grid');
test('invalid letter I',        'I 12345 67890',  r => r.route==='ig_grid_bad_letter');

// ── UK Grid paste ─────────────────────────────────────────────────────────────
console.log('\n── UK Grid paste ──');
// NS = {first:1, second:6} → easting base 100000, northing base 600000
test('10-digit no spaces',      'NS4514072887',   r => r.route==='uk_grid' && r.easting===145140 && r.northing===672887);
test('10-digit with spaces',    'NS 45140 72887', r => r.route==='uk_grid' && r.easting===145140 && r.northing===672887);
test('8-digit (4+4)',           'NS 4514 7288',   r => r.route==='uk_grid' && r.easting===145140 && r.northing===672880);
test('6-digit (3+3)',           'NS 451 728',     r => r.route==='uk_grid' && r.easting===145100 && r.northing===672800);
test('6-digit no spaces',       'NS451728',       r => r.route==='uk_grid' && r.easting===145100 && r.northing===672800);
test('4-digit (2+2)',           'NS 45 72',       r => r.route==='uk_grid' && r.easting===145000 && r.northing===672000);
test('2-digit (1+1)',           'NS 4 7',         r => r.route==='uk_grid' && r.easting===140000 && r.northing===670000);
test('lowercase letters',       'ns 45140 72887', r => r.route==='uk_grid');
test('SE ref',                  'SE 58098 29345', r => r.route==='uk_grid');
test('HP (Shetland)',            'HP 60000 10000', r => r.route==='uk_grid');
test('odd 5 digits → reject',   'NS12345',        r => r.route!=='uk_grid');
test('odd 7 digits → reject',   'NS1234567',      r => r.route!=='uk_grid');
test('11 digits → reject',      'NS12345678901',  r => r.route!=='uk_grid');
test('invalid square ZZ',       'ZZ 12345 67890', r => r.route==='uk_grid_bad_letter');

// ── WGS84 decimal ─────────────────────────────────────────────────────────────
console.log('\n── WGS84 decimal degrees ──');
test('simple lat,lon',           '53.3498, -6.2603',    r => r.route==='decimal_pair' && Math.abs(r.a-53.3498)<0.0001 && Math.abs(r.b-(-6.2603))<0.0001);
test('positive lon',             '1.2345, 36.8219',     r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('N/S/E/W prefix',           'N53.3498, W6.2603',   r => r.route==='decimal_pair' && Math.abs(r.a-53.3498)<0.0001 && Math.abs(r.b-(-6.2603))<0.0001);
test('trailing NSEW',            '53.3498N, 6.2603W',   r => r.route==='decimal_pair' && r.b < 0);
test('space-separated pair',     '53.3498 -6.2603',     r => r.route==='space_pair');
test('projected large coords',   '313621, 234156',      r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('lat exactly 90',           '90, 0',               r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('lat exactly -90',          '-90, 0',              r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('lon exactly 180',          '0, 180',              r => r.route==='decimal_pair' && r.suggestedFormat==='WGS84');
test('lat 90.1 → projected',     '90.1, 10',            r => r.route==='decimal_pair' && r.suggestedFormat==='projected');
test('lon 180.1 → projected',    '0, 180.1',            r => r.route==='decimal_pair' && r.suggestedFormat==='projected');

// ── DDM / DMS ─────────────────────────────────────────────────────────────────
console.log('\n── DDM / DMS ──');
test('DDM with NSEW',     "53° 20.988' N, 6° 15.619' W",   r => r.route==='decimal_pair' && Math.abs(r.a-53.3498)<0.001 && r.b < 0);
test('DMS with NSEW',     '53° 20\' 59" N, 6° 15\' 37" W', r => r.route==='decimal_pair' && r.a > 53 && r.b < 0);
test('DMS minus sign',    '-53° 20\' 59", -6° 15\' 37"',   r => r.route==='decimal_pair' && r.a < 0 && r.b < 0);
test('DDM no hemisphere', "53° 20.988', -6° 15.619'",      r => r.route==='decimal_pair');

// ── WKT ───────────────────────────────────────────────────────────────────────
console.log('\n── WKT ──');
test('POINT 2D',            'POINT (84092.667 53131.478)',     r => r.route==='wkt' && r.type==='POINT' && !r.hasZ);
test('POINT Z',             'POINT Z (1 1 5)',                 r => r.route==='wkt' && r.type==='Z' && r.hasZ && r.z===5);
test('POINT M',             'POINT M (1 1 80)',                r => r.route==='wkt' && r.type==='M' && !r.hasZ);
test('POINT ZM',            'POINT ZM (1 1 5 60)',             r => r.route==='wkt' && r.type==='ZM' && r.hasZ && r.z===5);
test('lowercase point',     'point (100 200)',                 r => r.route==='wkt');
test('negative coords',     'POINT (-6.260 53.349)',           r => r.route==='wkt' && r.x===-6.260 && r.y===53.349);
test('full feature dump',   'Geometry:: Point (84092.66714064161351416 53131.47802533095091349)\nfid: 15500\nSurvey: CWEF',
                                                               r => r.route==='wkt' && Math.abs(r.x-84092.667)<0.01);
test('LINESTRING → reject', 'LINESTRING (0 0, 1 1)',           r => r.route!=='wkt');
test('POINT missing paren', 'POINT 1 2',                       r => r.route!=='wkt');
test('POINT letters',       'POINT (abc def)',                 r => r.route!=='wkt');

// ── Plus Code ─────────────────────────────────────────────────────────────────
console.log('\n── Plus Code ──');
test('valid 10-char code',  '9C5P37C3+45',  r => r.route==='pluscode');
test('valid 11-char code',  '9C5P37C3+45J', r => r.route==='pluscode');
test('uppercase',           '9C5P37C3+45J', r => r.route==='pluscode');
test('no plus → unrecog',   '9C5P37C345J',  r => r.route!=='pluscode');
test('plus at wrong pos',   '9C5P+37C345J', r => r.route!=='pluscode');

// ── Edge / adversarial ───────────────────────────────────────────────────────
console.log('\n── Edge cases ──');
test('empty string',        '',             r => r.route==='empty');
test('null',                null,           r => r.route==='empty');
test('spaces only',         '   ',          r => r.route==='unrecognised');
test('single number',       '53.3498',      r => r.route==='unrecognised');
test('URL',                 'https://maps.google.com/?q=53.34,-6.26', r => r.route==='unrecognised');
test('plain text',          'Adrigole River survey point', r => r.route==='unrecognised');
test('1 letter only',       'H',            r => r.route==='unrecognised');
test('2 letters only',      'NS',           r => r.route==='unrecognised');
test('comma only',          ',',            r => r.route==='unrecognised');
test('NaN pair',            'abc, def',     r => r.route==='unrecognised');
test('very long string',    'A'.repeat(500), r => r.route!=='ig_grid');
test('mixed case WKT',      'pOiNt Z (1 2 3)', r => r.route==='wkt' && r.hasZ);
test('extra whitespace',    '  53.3498 ,  -6.2603  ', r => r.route==='decimal_pair');
test('tabs as separator',   '53.3498\t-6.2603', r => r.route==='space_pair');

// ── Summary ───────────────────────────────────────────────────────────────────
console.log(`\n── Results: ${passed} passed, ${failed} failed ──\n`);
if (failed > 0) process.exit(1);
