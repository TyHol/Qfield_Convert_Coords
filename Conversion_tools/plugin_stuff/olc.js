.pragma library

// Open Location Code (Plus Codes) encode/decode
// Ported from olc.py (Google LLC, Apache 2.0 licence)
// https://github.com/google/open-location-code

var SEPARATOR          = '+'
var SEPARATOR_POS      = 8
var PAD_CHAR           = '0'
var ALPHABET           = '23456789CFGHJMPQRVWX'
var BASE               = 20
var LAT_MAX            = 90
var LON_MAX            = 180
var MAX_DIGITS         = 15
var PAIR_LEN           = 10
var GRID_COLS          = 4
var GRID_ROWS          = 5

// Pre-computed precision constants
var PAIR_PRECISION     = BASE * BASE * BASE              // 8000
var FINAL_LAT_PREC    = PAIR_PRECISION * GRID_ROWS * GRID_ROWS * GRID_ROWS * GRID_ROWS * GRID_ROWS   // 8000 * 3125
var FINAL_LON_PREC    = PAIR_PRECISION * GRID_COLS * GRID_COLS * GRID_COLS * GRID_COLS * GRID_COLS   // 8000 * 1024
var PAIR_FIRST_PV     = BASE * BASE * BASE * BASE        // 20^4 = 160000
var GRID_LAT_FIRST_PV = GRID_ROWS * GRID_ROWS * GRID_ROWS * GRID_ROWS   // 5^4 = 625
var GRID_LON_FIRST_PV = GRID_COLS * GRID_COLS * GRID_COLS * GRID_COLS   // 4^4 = 256

function _clipLat(lat) { return Math.min(LAT_MAX,  Math.max(-LAT_MAX, lat)) }
function _normLon(lon) {
    while (lon < -LON_MAX) lon += 360
    while (lon >= LON_MAX) lon -= 360
    return lon
}
function _latPrecision(codeLen) {
    if (codeLen <= 10) return Math.pow(20, Math.floor(codeLen / -2 + 2))
    return Math.pow(20, -3) / Math.pow(GRID_ROWS, codeLen - 10)
}

// Encode a lat/lon into a Plus Code of the given length (default 10 = ~14×14m)
function encode(latitude, longitude, codeLength) {
    if (codeLength === undefined || codeLength === null) codeLength = PAIR_LEN
    codeLength = Math.max(2, Math.min(codeLength, MAX_DIGITS))
    latitude  = _clipLat(latitude)
    longitude = _normLon(longitude)
    if (latitude === LAT_MAX) latitude -= _latPrecision(codeLength)

    // Multiply to integer precision (round first to avoid float drift)
    var latVal = Math.floor(Math.round((latitude  + LAT_MAX) * FINAL_LAT_PREC * 1e6) / 1e6)
    var lonVal = Math.floor(Math.round((longitude + LON_MAX) * FINAL_LON_PREC * 1e6) / 1e6)

    var code = ''

    // Grid refinement digits (positions 11–15)
    if (codeLength > PAIR_LEN) {
        for (var g = 0; g < MAX_DIGITS - PAIR_LEN; g++) {
            var latD = latVal % GRID_ROWS
            var lonD = lonVal % GRID_COLS
            code    = ALPHABET[latD * GRID_COLS + lonD] + code
            latVal  = Math.floor(latVal / GRID_ROWS)
            lonVal  = Math.floor(lonVal / GRID_COLS)
        }
    } else {
        // Skip grid digits
        latVal = Math.floor(latVal / Math.pow(GRID_ROWS, MAX_DIGITS - PAIR_LEN))
        lonVal = Math.floor(lonVal / Math.pow(GRID_COLS, MAX_DIGITS - PAIR_LEN))
    }

    // Pair digits (positions 1–10)
    for (var p = 0; p < PAIR_LEN / 2; p++) {
        code   = ALPHABET[lonVal % BASE] + code
        code   = ALPHABET[latVal % BASE] + code
        latVal = Math.floor(latVal / BASE)
        lonVal = Math.floor(lonVal / BASE)
    }

    // Insert separator at position 8
    code = code.substring(0, SEPARATOR_POS) + SEPARATOR + code.substring(SEPARATOR_POS)

    if (codeLength >= SEPARATOR_POS) return code.substring(0, codeLength + 1)

    // Short code — pad remainder
    var padded = code.substring(0, codeLength)
    for (var i = padded.length; i < SEPARATOR_POS; i++) padded += PAD_CHAR
    return padded + SEPARATOR
}

// Returns true if the code is a valid full Plus Code
function isFull(code) {
    if (!code || typeof code !== 'string') return false
    code = code.toUpperCase()
    var sep = code.indexOf(SEPARATOR)
    if (sep < 0 || sep > SEPARATOR_POS || sep % 2 === 1) return false
    if (code.split(SEPARATOR).length - 1 > 1) return false
    if (code.length === 1) return false
    if (code.length - sep - 1 === 1) return false

    // Check padding
    var pad = code.indexOf(PAD_CHAR)
    if (pad >= 0) {
        if (sep < SEPARATOR_POS) return false
        if (pad === 0) return false
        var rpad = code.lastIndexOf(PAD_CHAR) + 1
        var pads = code.substring(pad, rpad)
        if (pads.length % 2 === 1) return false
        for (var pi = 0; pi < pads.length; pi++) if (pads[pi] !== PAD_CHAR) return false
        if (code[code.length - 1] !== SEPARATOR) return false
    }
    if (sep < SEPARATOR_POS) return false  // short code — not full

    for (var ci = 0; ci < code.length; ci++) {
        var ch = code[ci]
        if (ch === SEPARATOR || ch === PAD_CHAR) continue
        if (ALPHABET.indexOf(ch) === -1) return false
    }

    // Validate first lat/lon characters are in range
    if (ALPHABET.indexOf(code[0]) * BASE >= LAT_MAX * 2) return false
    if (code.length > 1 && ALPHABET.indexOf(code[1]) * BASE >= LON_MAX * 2) return false
    return true
}

// Decode a full Plus Code → {latitudeCenter, longitudeCenter} or null
function decode(code) {
    if (!isFull(code)) return null
    code = code.replace(/[+0]/g, '').toUpperCase().substring(0, MAX_DIGITS)

    var normalLat = -LAT_MAX * PAIR_PRECISION
    var normalLon = -LON_MAX * PAIR_PRECISION
    var gridLat = 0, gridLon = 0
    var digits = Math.min(code.length, PAIR_LEN)
    var pv = PAIR_FIRST_PV

    for (var i = 0; i < digits; i += 2) {
        normalLat += ALPHABET.indexOf(code[i])     * pv
        normalLon += ALPHABET.indexOf(code[i + 1]) * pv
        if (i < digits - 2) pv = Math.floor(pv / BASE)
    }
    var latPrec = pv / PAIR_PRECISION
    var lonPrec = pv / PAIR_PRECISION

    if (code.length > PAIR_LEN) {
        var rowpv = GRID_LAT_FIRST_PV
        var colpv = GRID_LON_FIRST_PV
        digits = Math.min(code.length, MAX_DIGITS)
        for (var j = PAIR_LEN; j < digits; j++) {
            var dv  = ALPHABET.indexOf(code[j])
            var row = Math.floor(dv / GRID_COLS)
            var col = dv % GRID_COLS
            gridLat += row * rowpv
            gridLon += col * colpv
            if (j < digits - 1) {
                rowpv = Math.floor(rowpv / GRID_ROWS)
                colpv = Math.floor(colpv / GRID_COLS)
            }
        }
        latPrec = rowpv / FINAL_LAT_PREC
        lonPrec = colpv / FINAL_LON_PREC
    }

    var lat = normalLat / PAIR_PRECISION + gridLat / FINAL_LAT_PREC
    var lon = normalLon / PAIR_PRECISION + gridLon / FINAL_LON_PREC
    return {
        latitudeCenter:  Math.min(lat + latPrec / 2, LAT_MAX),
        longitudeCenter: Math.min(lon + lonPrec / 2, LON_MAX)
    }
}
