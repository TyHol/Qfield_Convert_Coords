.pragma library

// Geohash encode / decode
// Based on the algorithm by Gustavo Niemeyer (2008). Public domain.
// Reference: https://en.wikipedia.org/wiki/Geohash

var CHARS = '0123456789bcdefghjkmnpqrstuvwxyz'; // base-32, no a/i/l/o

// Encode lat/lon to a geohash string.
// precision: number of characters (default 8 ≈ ±19 m — suitable for mountain rescue).
function encode(lat, lon, precision) {
    if (precision === undefined) precision = 8;
    var idx = 0, bit = 0, evenBit = true, geohash = '';
    var latMin = -90,  latMax = 90;
    var lonMin = -180, lonMax = 180;
    while (geohash.length < precision) {
        if (evenBit) {
            var lonMid = (lonMin + lonMax) / 2;
            if (lon >= lonMid) { idx = idx * 2 + 1; lonMin = lonMid; }
            else               { idx = idx * 2;     lonMax = lonMid; }
        } else {
            var latMid = (latMin + latMax) / 2;
            if (lat >= latMid) { idx = idx * 2 + 1; latMin = latMid; }
            else               { idx = idx * 2;     latMax = latMid; }
        }
        evenBit = !evenBit;
        if (++bit === 5) { geohash += CHARS[idx]; bit = 0; idx = 0; }
    }
    return geohash;
}

// Decode a geohash string to {lat, lon} (centre of cell), or null if invalid.
function decode(geohash) {
    var b = decodeBounds(geohash);
    if (b === null) return null;
    return { lat: (b.minLat + b.maxLat) / 2,
             lon: (b.minLon + b.maxLon) / 2 };
}

// Return {minLat, maxLat, minLon, maxLon} for a geohash, or null if invalid.
function decodeBounds(geohash) {
    geohash = geohash.toLowerCase();
    var evenBit = true;
    var latMin = -90,  latMax = 90;
    var lonMin = -180, lonMax = 180;
    for (var i = 0; i < geohash.length; i++) {
        var idx2 = CHARS.indexOf(geohash[i]);
        if (idx2 === -1) return null;
        for (var bits = 4; bits >= 0; bits--) {
            var bitN = (idx2 >> bits) & 1;
            if (evenBit) {
                var lonMid2 = (lonMin + lonMax) / 2;
                if (bitN === 1) lonMin = lonMid2; else lonMax = lonMid2;
            } else {
                var latMid2 = (latMin + latMax) / 2;
                if (bitN === 1) latMin = latMid2; else latMax = latMid2;
            }
            evenBit = !evenBit;
        }
    }
    return { minLat: latMin, maxLat: latMax, minLon: lonMin, maxLon: lonMax };
}

// Return true if s is a plausible geohash (6–12 base-32 chars, no spaces).
function isValid(s) {
    return typeof s === 'string' &&
           /^[0-9bcdefghjkmnpqrstuvwxyz]{6,12}$/i.test(s);
}
