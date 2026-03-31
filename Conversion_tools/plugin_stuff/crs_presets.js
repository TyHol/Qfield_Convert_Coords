.pragma library

// Curated list of ~70 common CRS for Europe / UK / Ireland
// Each entry: {name, code}  — code is the EPSG integer as a string
var list = [

    // --- Ireland / UK ---
    {name: "Irish Transverse Mercator (ITM)",   code: "2157"},
    {name: "Irish Grid (TM75)",                  code: "29903"},
    {name: "Irish Grid (TM65)",                  code: "29902"},
    {name: "Irish Grid (TM65 deprecated)",       code: "29900"},
    {name: "IRENET95 geographic",                code: "4173"},
    {name: "British National Grid (OSGB36)",     code: "27700"},
    {name: "OSGB36 geographic",                  code: "4277"},

    // --- Geographic / Global ---
    {name: "WGS84 geographic (2D)",              code: "4326"},
    {name: "WGS84 geographic (3D)",              code: "4979"},
    {name: "ETRS89 geographic (2D)",             code: "4258"},
    {name: "ETRS89 geographic (3D)",             code: "4937"},
    {name: "ED50 geographic",                    code: "4230"},
    {name: "NAD83 geographic",                   code: "4269"},

    // --- Web / Tiles ---
    {name: "Web Mercator (Google/OSM tiles)",    code: "3857"},
    {name: "World Mercator",                     code: "3395"},

    // --- ETRS89 UTM zones (Europe) ---
    {name: "ETRS89 / UTM zone 26N (Azores)",    code: "25826"},
    {name: "ETRS89 / UTM zone 27N (Iceland)",   code: "25827"},
    {name: "ETRS89 / UTM zone 28N (W Africa)",  code: "25828"},
    {name: "ETRS89 / UTM zone 29N (W Ireland)", code: "25829"},
    {name: "ETRS89 / UTM zone 30N (UK/Ireland)",code: "25830"},
    {name: "ETRS89 / UTM zone 31N (W Europe)",  code: "25831"},
    {name: "ETRS89 / UTM zone 32N (C Europe)",  code: "25832"},
    {name: "ETRS89 / UTM zone 33N (Scandinavia)",code: "25833"},
    {name: "ETRS89 / UTM zone 34N (E Europe)",  code: "25834"},
    {name: "ETRS89 / UTM zone 35N (Finland/Baltic)", code: "25835"},
    {name: "ETRS89 / UTM zone 36N",             code: "25836"},
    {name: "ETRS89 / UTM zone 37N",             code: "25837"},
    {name: "ETRS89 / UTM zone 38N",             code: "25838"},

    // --- WGS84 UTM zones (Europe / N Africa) ---
    {name: "WGS84 / UTM zone 28N",              code: "32628"},
    {name: "WGS84 / UTM zone 29N",              code: "32629"},
    {name: "WGS84 / UTM zone 30N",              code: "32630"},
    {name: "WGS84 / UTM zone 31N",              code: "32631"},
    {name: "WGS84 / UTM zone 32N",              code: "32632"},
    {name: "WGS84 / UTM zone 33N",              code: "32633"},
    {name: "WGS84 / UTM zone 34N",              code: "32634"},
    {name: "WGS84 / UTM zone 35N",              code: "32635"},
    {name: "WGS84 / UTM zone 36N",              code: "32636"},
    {name: "WGS84 / UTM zone 37N",              code: "32637"},
    {name: "WGS84 / UTM zone 38N",              code: "32638"},

    // --- Pan-European ---
    {name: "ETRS89 / LAEA Europe (statistics)", code: "3035"},
    {name: "ETRS89 / LCC Europe",               code: "3034"},

    // --- France ---
    {name: "RGF93 / Lambert 93 (France)",       code: "2154"},
    {name: "RGF93 geographic",                  code: "4171"},

    // --- Belgium ---
    {name: "Belgian Lambert 1972",              code: "31370"},

    // --- Netherlands ---
    {name: "RD New (Netherlands)",              code: "28992"},

    // --- Germany ---
    {name: "DHDN / Gauss-Kruger zone 2",        code: "31466"},
    {name: "DHDN / Gauss-Kruger zone 3",        code: "31467"},
    {name: "DHDN / Gauss-Kruger zone 4",        code: "31468"},
    {name: "DHDN / Gauss-Kruger zone 5",        code: "31469"},
    {name: "ETRS89 / UTM zone 32N (N) DE",      code: "4647"},

    // --- Sweden ---
    {name: "SWEREF99 TM (Sweden)",              code: "3006"},
    {name: "SWEREF99 12 00 (Sweden)",           code: "3008"},

    // --- Finland ---
    {name: "ETRS89 / TM35FIN (Finland)",        code: "3067"},
    {name: "KKJ / Finland Uniform CS",          code: "2393"},

    // --- Baltic States ---
    {name: "LKS92 / Latvia TM",                 code: "3059"},
    {name: "Estonian CS97 (L-EST97)",           code: "3301"},
    {name: "LKS94 / Lithuania TM",              code: "3346"},

    // --- Switzerland ---
    {name: "CH1903+ / LV95 (Switzerland)",      code: "2056"},
    {name: "CH1903 / LV03 (Switzerland old)",   code: "21781"},

    // --- Austria ---
    {name: "MGI / Austria Lambert",             code: "31287"},
    {name: "MGI geographic",                    code: "4312"},

    // --- Hungary ---
    {name: "HD72 / EOV (Hungary)",              code: "23700"},

    // --- Czech Republic / Slovakia ---
    {name: "S-JTSK / Krovak East North (CZ/SK)",code: "5514"},

    // --- Poland ---
    {name: "ETRS89 / Poland CS92",              code: "2180"},

    // --- Portugal ---
    {name: "ETRS89 / Portugal TM06",            code: "3763"},

    // --- Spain (ED50 UTM) ---
    {name: "ED50 / UTM zone 29N (Spain/Portugal)", code: "23029"},
    {name: "ED50 / UTM zone 30N (Spain)",       code: "23030"},
    {name: "ED50 / UTM zone 31N (NE Spain)",    code: "23031"},

    // --- Romania ---
    {name: "Stereo70 (Romania)",                code: "3844"},

]
