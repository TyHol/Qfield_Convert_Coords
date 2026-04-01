.pragma library

// MGRS encode/decode — pure JS, no projection math.
// Projection (WGS84 ↔ UTM) is done by QField's GeometryUtils; this file
// only handles the UTM easting/northing ↔ MGRS grid-letter arithmetic.
//
// Ported from mgrs.py (Alex Bruy / Planet Federal, GPL v2+).
// Covers UTM zones only (lat -80° to +84°). UPS polar regions not implemented.

var ONEHT  = 100000.0
var TWOMIL = 2000000.0

// Latitude band data: [letterIdx, minNorthing, upperLat, lowerLat, northingOffset]
// letterIdx: A=0…Z=25 (I=8 and O=14 are never used as band letters)
var LAT_BANDS = [
    [ 2, 1100000.0, -72.0, -80.5,       0.0],  // C
    [ 3, 2000000.0, -64.0, -72.0, 2000000.0],  // D
    [ 4, 2800000.0, -56.0, -64.0, 2000000.0],  // E
    [ 5, 3700000.0, -48.0, -56.0, 2000000.0],  // F
    [ 6, 4600000.0, -40.0, -48.0, 4000000.0],  // G
    [ 7, 5500000.0, -32.0, -40.0, 4000000.0],  // H
    [ 9, 6400000.0, -24.0, -32.0, 6000000.0],  // J
    [10, 7300000.0, -16.0, -24.0, 6000000.0],  // K
    [11, 8200000.0,  -8.0, -16.0, 8000000.0],  // L
    [12, 9100000.0,   0.0,  -8.0, 8000000.0],  // M
    [13,       0.0,   8.0,   0.0,       0.0],  // N
    [15,  800000.0,  16.0,   8.0,       0.0],  // P
    [16, 1700000.0,  24.0,  16.0,       0.0],  // Q
    [17, 2600000.0,  32.0,  24.0, 2000000.0],  // R
    [18, 3500000.0,  40.0,  32.0, 2000000.0],  // S
    [19, 4400000.0,  48.0,  40.0, 4000000.0],  // T
    [20, 5300000.0,  56.0,  48.0, 4000000.0],  // U
    [21, 6200000.0,  64.0,  56.0, 6000000.0],  // V
    [22, 7000000.0,  72.0,  64.0, 6000000.0],  // W
    [23, 7900000.0,  84.5,  72.0, 6000000.0]   // X
]

function _letter(idx) { return String.fromCharCode(idx + 65) }
function _idx(ch)     { return ch.toUpperCase().charCodeAt(0) - 65 }

function _pad5(n) {
    var s = '' + Math.floor(n)
    while (s.length < 5) s = '0' + s
    return s
}

// Latitude band letter index for a given latitude
function _latBandIdx(lat) {
    if (lat >= 72 && lat < 84.5) return 23  // X
    if (lat > -80.5 && lat < 72) {
        var i = Math.floor((lat + 80.0) / 8.0 + 1e-12)
        return LAT_BANDS[i][0]
    }
    return -1
}

// Grid column/row letter sets and pattern offset for a UTM zone
function _gridValues(zone) {
    var s = zone % 6
    if (s === 0) s = 6
    var lo, hi
    if (s === 1 || s === 4) { lo = 0;  hi = 7  }  // A–H
    else if (s === 2 || s === 5) { lo = 9;  hi = 17 }  // J–R (no I=8)
    else                         { lo = 18; hi = 25 }  // S–Z
    return { lo: lo, hi: hi, offset: (s % 2 === 1) ? 0.0 : 500000.0 }
}

// minNorthing and northingOffset for a latitude-band letter index
function _bandNorthing(letterIdx) {
    for (var i = 0; i < LAT_BANDS.length; i++) {
        if (LAT_BANDS[i][0] === letterIdx)
            return { minN: LAT_BANDS[i][1], offset: LAT_BANDS[i][4] }
    }
    return null
}

// Return {hemisphere, zone, epsg} for a WGS84 lat/lon, or null if polar (|lat|>84)
function epsgForLatLon(lat, lon) {
    if (Math.abs(lat) > 90 || lon < -180 || lon > 360) return null
    if (lat <= -80 || lat >= 84) return null  // UPS — not supported
    var hemi = lat < 0 ? 'S' : 'N'
    var zone
    if (lon < 180) zone = Math.floor(31 + lon / 6.0)
    else           zone = Math.floor(lon / 6.0 - 29)
    if (zone > 60) zone = 1
    // Svalbard/Norway special zones
    if (lat >= 56 && lat < 64 && lon >= 3  && lon < 12) zone = 32
    if (lat >= 72 && lat < 84) {
        if      (lon >= 0  && lon < 9)  zone = 31
        else if (lon >= 9  && lon < 21) zone = 33
        else if (lon >= 21 && lon < 33) zone = 35
        else if (lon >= 33 && lon < 42) zone = 37
    }
    var ns = hemi === 'N' ? 600 : 700
    return { hemisphere: hemi, zone: zone, epsg: 32000 + ns + zone }
}

// EPSG from UTM zone + hemisphere
function epsgForUtm(zone, hemisphere) {
    return 32000 + (hemisphere === 'N' ? 600 : 700) + zone
}

// Convert UTM → MGRS string
// lat is the WGS84 latitude (needed only for latitude band letter)
// easting / northing are UTM metres in the appropriate EPSG
// precision: 0 (100km) … 5 (1m), default 5
function utmToMgrs(zone, hemisphere, lat, easting, northing, precision) {
    if (precision === undefined || precision === null) precision = 5
    precision = Math.max(0, Math.min(5, precision))

    // Special: equator / S-hemisphere edge
    if (lat <= 0.0 && northing === 1.0e7) { lat = 0; northing = 0 }

    var gv = _gridValues(zone)
    var bandIdx = _latBandIdx(lat)
    if (bandIdx < 0) return ""

    // Row letter: northing mod 2,000,000 + pattern offset → row index
    var n = northing
    while (n >= TWOMIL) n -= TWOMIL
    n += gv.offset
    if (n >= TWOMIL) n -= TWOMIL

    var rowIdx = Math.floor(n / ONEHT)
    if (rowIdx > 7)  rowIdx++   // skip I (8)
    if (rowIdx > 13) rowIdx++   // skip O (14)

    // Column letter
    if (zone === 31 && bandIdx === 21 && easting === 500000.0) easting -= 1.0
    var colIdx = gv.lo + Math.floor(easting / ONEHT) - 1
    if (gv.lo === 9 && colIdx > 13) colIdx++  // skip O in J-R set

    var zoneStr = zone < 10 ? '0' + zone : '' + zone
    var letters = _letter(bandIdx) + _letter(colIdx) + _letter(rowIdx)

    var e = (easting  + 1e-8) % ONEHT; if (e >= 99999.5) e = 99999.0
    var nr = (northing + 1e-8) % ONEHT; if (nr >= 99999.5) nr = 99999.0

    var eStr = _pad5(e).substring(0, precision)
    var nStr = _pad5(nr).substring(0, precision)
    return zoneStr + letters + eStr + nStr
}

// Parse an MGRS string → {zone, hemisphere, easting, northing} or null
function mgrsToUtm(mgrsStr) {
    var s = mgrsStr.replace(/\s+/g, '').toUpperCase()
    // Ensure two-digit zone prefix
    var firstIsDigit = s.length > 0 && s[0] >= '0' && s[0] <= '9'
    var secondIsDigit = s.length > 1 && s[1] >= '0' && s[1] <= '9'
    if (firstIsDigit && !secondIsDigit) s = '0' + s
    else if (!firstIsDigit)             s = '00' + s

    var zone = parseInt(s.substring(0, 2))
    if (zone < 1 || zone > 60) return null

    if (s.length < 5) return null
    var l0 = _idx(s[2]), l1 = _idx(s[3]), l2 = _idx(s[4])
    var invalid = [8, 14]  // I, O
    if (invalid.indexOf(l0) >= 0 || invalid.indexOf(l1) >= 0 || invalid.indexOf(l2) >= 0) return null
    if (l2 > 21) return null  // row letters only go to V (21)

    var numStr = s.substring(5)
    if (numStr.length % 2 !== 0 || numStr.length > 10) return null
    var precision = numStr.length / 2
    var scale = Math.pow(10, 5 - precision)
    var easting  = precision > 0 ? parseFloat(numStr.substring(0, precision)) * scale : 0
    var northing = precision > 0 ? parseFloat(numStr.substring(precision))    * scale : 0

    // Hemisphere from latitude band: C–M (idx 2–12) = S, N–X (idx 13–23) = N
    var hemisphere = l0 < 13 ? 'S' : 'N'

    var gv = _gridValues(zone)
    if (l1 < gv.lo || l1 > gv.hi) return null

    // Row letter → northing within 2km cycle
    var rowN = l2 * ONEHT
    if (l2 > 14) rowN -= ONEHT  // compensate for skipped O
    if (l2 > 8)  rowN -= ONEHT  // compensate for skipped I
    if (rowN >= TWOMIL) rowN -= TWOMIL

    // Column letter → easting
    var gridE = (l1 - gv.lo + 1) * ONEHT
    if (gv.lo === 9 && l1 > 14) gridE -= ONEHT  // compensate for skipped O in J-R set

    // Recover absolute northing
    var bn = _bandNorthing(l0)
    if (!bn) return null

    var gridN = rowN - gv.offset
    if (gridN < 0) gridN += TWOMIL
    gridN += bn.offset
    if (gridN < bn.minN) gridN += TWOMIL

    easting  += gridE
    northing += gridN

    return { zone: zone, hemisphere: hemisphere, easting: easting, northing: northing }
}
