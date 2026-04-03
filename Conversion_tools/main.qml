import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield
import org.qgis
import QtCore

import Theme

import "qrc:/qml" as QFieldItems
import "plugin_stuff"
import "plugin_stuff/mgrs.js" as Mgrs
import "plugin_stuff/olc.js"  as OLC

Item {
 id: plugin

 property var canvas: iface.mapCanvas().mapSettings
 property var mainWindow: iface.mainWindow()
 property var dashBoard: iface.findItemByObjectName('dashBoard')
 property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')
 property var positionSource: iface.findItemByObjectName('positionSource')
 property var canvasMenu: iface.findItemByObjectName('canvasMenu')
 property var codeReader: iface.findItemByObjectName('codeReader')
 property bool _qrScanPending: false
 property var canvasCrs : canvas.destinationCrs ;
 property var canvasEPSG : parseInt(canvasCrs.authid.split(":")[1]); // Canvas destination CRS (not project CRS)
 property var mapCanvas: iface.mapCanvas()




//changable stuff 
property var filetimedate : "v2.3.0  03.04.26" // version date
property var mapsUrlOption: 3 // Default external map: 1=GMaps pin, 2=GMaps nav, 3=OSM, 4=OSRM route
property var _lastX: 0; property var _lastY: 0; property var _lastEPSG: 4326 // last coords for re-render on setting change
property string _lastWarnedEPSGs: "" // tracks last EPSG combo that triggered a Helmert warning
property string lastEditedBox: "dms_boxes" // tracks which input box was last edited
property bool coordinatesDirty: false          // true when a box has been edited but not yet converted

//default values
property var fsize : "15" // general font size
property int zoomPresetDefault: 3  // default zoom preset index (0=Detail … 5=Country)
property var decm : "0"  // decimal places for meter coordinates
property var decd : "5"  // decimal places for degree coordinates
  
 //Default visibility of various boxes
property var igvis: true // visibility of Irish grid
property var ukgvis: false // visibility of UK grid
property var custom1vis: false // visibility of custom1
property var custom2vis: false // visibility of custom2 
property var wgs84vis: true // visibility of wgs84 // always visible
property var dmvis: true // visibility of DM
property var dmsvis: false // visibility of DMS
property var dmsBoxesvis: false // visibility of DMS boxes
property var customisationvis: false // visibility of customisation
property var crosshairvis: true // visibility of crosshair
property var mgrsvis:     false // visibility of MGRS row
property var pluscodevis: false // visibility of Plus Code row
property var  showFeatureFormDefault: true // whether Add opens attribute form
property bool formOnAdd: true             // live mirror of showFeatureForm setting
property var afterAddDefault: 1           // 0=nothing, 1=pan to, 2=zoom to
property bool pendingAlwaysZoom: false    // set before pasteFormatDialog.open(); read in onAccepted
// for testing:
property var degwa : "70"  // width of degree input box when no decimals in it
property var minwa : "70"  // width of minute input box when no decimals in degree box



Settings {
    id: appSettings
    category: "ConversionTools"
    property string pointLayerName: ""
    property int    mapsUrlOption:  3
    property string fontSize:       "15"
    property int    zoomPreset:     2
    property string decimalsM:      "0"
    property string decimalsD:      "5"
    property bool   showIG:         true
    property bool   showUK:         false
    property bool   showDegrees:    false
    property bool   showDM:         true
    property bool   showDMS:        false
    property bool   showCustom1:    false
    property bool   showCustom2:    false
    property bool   showMGRS:       false
    property bool   showPlusCode:   false
    property bool   showCrosshair:  true
    property bool   showDMSboxes:   false
    property bool   showCustomisation: false
    property bool   showFeatureForm: true
    property int    afterAddAction:  1
    property bool   useNSEW:        false
    property string crs1:           ""
    property string crs2:           "4326"
}

ListModel { id: pointLayerPickerModel }

function populatePointLayerPicker() {
    pointLayerPickerModel.clear()

    var layers = ProjectUtils.mapLayers(qgisProject)
    var normalLayers = []
    var privateLayers = []

    // Collect valid editable point layers, split by private flag (value 4)
    for (var id in layers) {
        var layer = layers[id]
        try {
            if (layer &&
                layer.geometryType &&
                layer.geometryType() === Qgis.GeometryType.Point &&
                layer.supportsEditing === true) {

                var isPrivate = false
                try { isPrivate = (layer.flags & 8) !== 0 } catch (e2) {}

                if (isPrivate)
                    privateLayers.push(layer)
                else
                    normalLayers.push(layer)
            }
        } catch (e) {}
    }

    // Sort each group alphabetically
    normalLayers.sort(function(a, b) { return a.name.localeCompare(b.name) })
    privateLayers.sort(function(a, b) { return a.name.localeCompare(b.name) })

    // If no layers found at all, show a placeholder and bail out
    if (normalLayers.length === 0 && privateLayers.length === 0) {
        pointLayerPickerModel.append({ "name": qsTr("— no editable point layers —"), "isHeader": true })
        pointLayerCombo.currentIndex = 0
        appSettings.pointLayerName = ""
        return
    }

    // Layers exist — add "Active Layer" as first selectable option
    pointLayerPickerModel.append({ "name": qsTr("Active Layer"), "isHeader": false })

    // Append normal layers
    for (var i = 0; i < normalLayers.length; i++)
        pointLayerPickerModel.append({ "name": normalLayers[i].name, "isHeader": false })

    // Append private group header + private layers (if any)
    if (privateLayers.length > 0) {
        pointLayerPickerModel.append({ "name": qsTr("— Private Layers —"), "isHeader": true })
        for (var j = 0; j < privateLayers.length; j++)
            pointLayerPickerModel.append({ "name": privateLayers[j].name, "isHeader": false })
    }

    // Restore saved selection
    var saved = appSettings.pointLayerName
    var found = false
    for (var k = 1; k < pointLayerPickerModel.count; k++) {
        var item = pointLayerPickerModel.get(k)
        if (!item.isHeader && item.name === saved) {
            pointLayerCombo.currentIndex = k
            found = true
            break
        }
    }
    if (!found) {
        pointLayerCombo.currentIndex = 0
        appSettings.pointLayerName = ""
    }
}


Component.onCompleted: {
    iface.addItemToPluginsToolbar(mainPluginButton)
    igukGridsFilter2.locatorBridge.registerQFieldLocatorFilter(igukGridsFilter2);
    canvasMenu.addItem(navButton)
    canvasMenu.addItem(addPointButton)
    canvasMenu.addItem(convertButton)
    canvasMenu.addItem(pasteButton)
    // Restore saved settings into UI
    mapsUrlOption      = appSettings.mapsUrlOption
    font_Size.text     = appSettings.fontSize
    zoomPresetCombo.currentIndex = appSettings.zoomPreset
    decimalsm.text     = appSettings.decimalsM
    decimalsd.text     = appSettings.decimalsD
    showIG.checked     = appSettings.showIG
    showUK.checked     = appSettings.showUK
    showDegrees.checked    = appSettings.showDegrees
    showDM.checked         = appSettings.showDM
    showDMS.checked        = appSettings.showDMS
    showCustom1.checked    = appSettings.showCustom1
    showCustom2.checked    = appSettings.showCustom2
    showMGRS.checked       = appSettings.showMGRS
    showPlusCode.checked   = appSettings.showPlusCode
    showCrosshair.checked  = appSettings.showCrosshair
    showDMSboxes.checked   = appSettings.showDMSboxes
    showCustomisation.checked = appSettings.showCustomisation
    formOnAdd = appSettings.showFeatureForm
    showFormOnAdd.checked = formOnAdd
    afterAddGroup.checkedButton = [afterAddNothing, afterAddPan, afterAddZoom][appSettings.afterAddAction]
}

 Component.onDestruction: { 
    igukGridsFilter2.locatorBridge.deregisterQFieldLocatorFilter(igukGridsFilter2);
    }   

    // --- Refactored Functions ---

    // Returns true if the EPSG code in epsgText refers to a geographic CRS (degrees),
    // false if projected (metres). Falls back to false on any error.
    function crsIsGeographic(epsgText) {
        try {
            return CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(epsgText)).isGeographic
        } catch(e) { return false }
    }

    // Clears error state on all input boxes
    function _clearErrors() {
        igInputBox.hasError    = false
        ukInputBox.hasError    = false
        custom1BoxXY.hasError  = false
        custom2BoxXY.hasError  = false
        wgs84Box.hasError      = false
        wgs84DMBox.hasError    = false
        wgs84DMSBox.hasError   = false
        mgrsBox.hasError       = false
        pluscodeBox.hasError   = false
    }

    // Marks a box as invalid and shows a toast
    function _setError(box, msg) {
        _clearErrors()
        box.hasError = true
        mainWindow.displayToast(qsTr(msg))
    }


    function copyToClipboard(textToCopy) {
        let textEdit = Qt.createQmlObject('import QtQuick; TextEdit { }', plugin);
        textEdit.text = textToCopy;
        textEdit.selectAll();
        textEdit.copy();
        textEdit.destroy();
        mainWindow.displayToast("Copied: " + textToCopy);
    }

    // Formats a grid reference input box as the user types.
    // letterCount=1 for Irish Grid (single letter), 2 for UK Grid (two letters).
    // Strips non-alphanumeric characters, validates the prefix against letterMatrix,
    // and inserts spaces: "PREFIX EEEEE NNNNN".
    function formatGridInput(inputBox, letterMatrix, letterCount) {
        var raw = inputBox.text.replace(/[^A-Za-z0-9]/g, '')
        if (raw.length < letterCount) return
        var prefix = raw.substring(0, letterCount).toUpperCase()
        if (!letterMatrix[prefix]) return
        var digits = raw.substring(letterCount).replace(/\D/g, '').substring(0, 10)
        var cleanedText
        if (digits.length === 0) {
            cleanedText = prefix
        } else if (digits.length <= 5) {
            cleanedText = prefix + ' ' + digits
        } else {
            cleanedText = prefix + ' ' + digits.substring(0, 5) + ' ' + digits.substring(5)
        }
        if (inputBox.text !== cleanedText) { inputBox.isProgrammaticUpdate = true; inputBox.text = cleanedText }
    }

    // Updates DMS box visibility based on whether degrees/minutes contain decimals.
    // Called from latDegrees and lonDegrees onTextChanged — logic is identical in both.
    function updateDMSBoxVisibility() {
        if (lonDegrees.text.includes('.') || latDegrees.text.includes('.')) {
            latMinutes.visible = false; latMinutes.text = ""
            latSeconds.visible = false; latSeconds.text = ""
            lonMinutes.visible = false; lonMinutes.text = ""
            lonSeconds.visible = false; lonSeconds.text = ""
        } else if (lonMinutes.text.includes('.') || latMinutes.text.includes('.')) {
            lonDegrees.Layout.preferredWidth = degwa
            latDegrees.Layout.preferredWidth = degwa
            latMinutes.visible = true
            latSeconds.visible = false; latSeconds.text = ""
            lonMinutes.visible = true
            lonSeconds.visible = false; lonSeconds.text = ""
        } else {
            lonDegrees.Layout.preferredWidth = degwa
            latDegrees.Layout.preferredWidth = degwa
            latMinutes.visible = true
            lonMinutes.visible = true
            lonMinutes.Layout.preferredWidth = minwa
            latMinutes.Layout.preferredWidth = minwa
            latSeconds.visible = true
            lonSeconds.visible = true
        }
    }

    // Parses the WGS84 box text into {lat, lon} regardless of whether useNSEW is on.
    // Handles both "53.349, -6.260" and "53.349 N, 6.260 W".
    function parseWgs84BoxCoords() {
        var parts = wgs84Box.text.split(',')
        if (parts.length < 2) return null
        function applyHemi(s) {
            s = s.trim()
            var m = s.match(/^([-\d.]+)\s*([NSEWnsew]?)$/)
            if (!m) return NaN
            var v = parseFloat(m[1])
            var h = m[2].toUpperCase()
            if (h === 'S' || h === 'W') v = -Math.abs(v)
            return v
        }
        var lat = applyHemi(parts[0])
        var lon = applyHemi(parts[1])
        if (isNaN(lat) || isNaN(lon)) return null
        return { lat: lat, lon: lon }
    }

    // Builds the external map URL for a WGS84 destination (lat/lon).
    // Option 4 (OSRM routing) also resolves a GPS or screen-centre origin.
    function buildMapsUrl(lat, lon) {
        if (mapsUrlOption === 1)
            return "https://www.google.com/maps/search/?api=1&query=" + lat + "," + lon;
        if (mapsUrlOption === 2)
            return "https://www.google.com/maps/dir/?api=1&destination=" + lat + "%2C" + lon + "&travelmode=driving";
        if (mapsUrlOption === 3)
            return "https://www.openstreetmap.org/#map=15/" + lat + "/" + lon;
        // option 4 — OSRM routing, needs an origin
        var gpsLat, gpsLon;
        if (positionSource.active && positionSource.positionInformation.latitudeValid && positionSource.positionInformation.longitudeValid) {
            gpsLat = positionSource.positionInformation.latitude;
            gpsLon = positionSource.positionInformation.longitude;
            mainWindow.displayToast("Routing from GPS position");
        } else {
            var cp = GeometryUtils.reprojectPoint(
                canvas.center, canvasCrs,
                CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"));
            gpsLat = cp.y;
            gpsLon = cp.x;
            mainWindow.displayToast("No GPS — routing from screen centre");
        }
        return "https://routing.openstreetmap.de/?z=10&center=" + gpsLat + "%2C" + gpsLon
             + "&loc=" + gpsLat + "%2C" + gpsLon
             + "&loc=" + lat + "%2C" + lon
             + "&hl=en&alt=0&srv=0";
    }

    // Shared entry point for all "add point" actions.
    // geometry: already-built QgsGeometry in canvas CRS
    // openForm:  true  → open feature attribute form (button / locator)
    //            false → commit silently (paste)
    function addPointToActiveLayer(geometry, openForm) {
        var layer = null
        var savedName = appSettings.pointLayerName
        if (savedName !== "") {
            layer = qgisProject.mapLayersByName(savedName)[0] || null
            if (!layer) {
                mainWindow.displayToast(qsTr("Saved layer '%1' not found — using active layer").arg(savedName))
                appSettings.pointLayerName = ""
                pointLayerCombo.currentIndex = 0
            }
        }
        if (!layer) {
            dashBoard.ensureEditableLayerSelected()
            if (!dashBoard.activeLayer) {
                mainWindow.displayToast("No active layer selected")
                return
            }
            if (dashBoard.activeLayer.geometryType() !== Qgis.GeometryType.Point) {
                mainWindow.displayToast(qsTr("Active vector layer must be a point geometry"))
                return
            }
            layer = dashBoard.activeLayer
        }
        // Reproject geometry from canvas CRS to the layer's own CRS if they differ.
        // boundingBox on a point gives a degenerate rect where xMin==xMax, yMin==yMax,
        // so it's a safe way to extract coordinates from an opaque QgsGeometry.
        var layerCrs = layer.crs
        var canvasCrsObj = mapCanvas.mapSettings.destinationCrs
        if (layerCrs.authid !== canvasCrsObj.authid) {
            var bbox = GeometryUtils.boundingBox(geometry)
            var reproj = GeometryUtils.reprojectPoint(
                GeometryUtils.point(bbox.xMinimum, bbox.yMinimum),
                canvasCrsObj, layerCrs)
            geometry = GeometryUtils.createGeometryFromWkt(`POINT(${reproj.x} ${reproj.y})`)
        }
        var feature = FeatureUtils.createFeature(layer, geometry)

        // ── Open form or silent add ───────────────────────────────────────
        if (openForm) {
            dashBoard.activeLayer = layer
            overlayFeatureFormDrawer.featureModel.feature = feature
            overlayFeatureFormDrawer.state = "Add"
            overlayFeatureFormDrawer.featureModel.resetAttributes(true)
            overlayFeatureFormDrawer.open()
        } else {
            layer.startEditing()
            if (LayerUtils.addFeature(layer, feature)) {
                layer.commitChanges()
                mainWindow.displayToast(qsTr("Point added to '%1' (note: hard field constraints are not checked in silent mode)").arg(layer.name))
            } else {
                layer.rollBack()
                mainWindow.displayToast(qsTr("Could not add point — try enabling 'Form on add'"))
            }
        }
    }

    // Called by the paste handler — reprojects to canvas CRS then adds silently.
    function addPoint(pointX, pointY, crsEpsg, pointZ) {
        var pt = (crsEpsg !== canvasEPSG)
            ? GeometryUtils.reprojectPoint(
                GeometryUtils.point(pointX, pointY),
                CoordinateReferenceSystemUtils.fromDescription("EPSG:" + crsEpsg),
                CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG))
            : GeometryUtils.point(pointX, pointY);
        var wkt = (pointZ !== undefined && !isNaN(pointZ))
            ? `POINT Z(${pt.x} ${pt.y} ${pointZ})`
            : `POINT(${pt.x} ${pt.y})`
        addPointToActiveLayer(GeometryUtils.createGeometryFromWkt(wkt), false);
    }

    // Zooms the map canvas to a point, creating a square extent around it.
    // The half-width of that square is controlled by the Zoom setting (1-10):
    //   offset = exp(zoomLevel × 1.8)  → metres for projected CRS
    // For geographic CRS the offset is converted from metres to degrees
    // using the approximation 1° ≈ 111 000 m.
    function zoomToPoint(pointX, pointY, crsEpsg) {
        var sourceCrs = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + crsEpsg);
        var canvasCrsObj = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG);
        var transformedPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(pointX, pointY), sourceCrs, canvasCrsObj);

        // Named presets: Building=50m, Street=500m, Town=2km, Region=20km, Country=200km
        var presetOffsets = [25, 50, 500, 2000, 20000, 200000]
        var offset = presetOffsets[appSettings.zoomPreset] || 2000
        if (canvasCrs.isGeographic) { offset = offset / 111000; } // metres → degrees

        var xMin = transformedPoint.x - offset;
        var xMax = transformedPoint.x + offset;
        var yMin = transformedPoint.y - offset;
        var yMax = transformedPoint.y + offset;

        var polygonWkt = `POLYGON((${xMin} ${yMin}, ${xMax} ${yMin}, ${xMax} ${yMax}, ${xMin} ${yMax}, ${xMin} ${yMin}))`;
        var geometry = GeometryUtils.createGeometryFromWkt(polygonWkt);

        const extent = GeometryUtils.reprojectRectangle(
            GeometryUtils.boundingBox(geometry),
            canvasCrsObj,
            mapCanvas.mapSettings.destinationCrs
        );
        mapCanvas.mapSettings.setExtent(extent, true);
    }

    // Pan or zoom to a point after adding it, based on the afterAddAction setting.
    // x, y are in the CRS given by crsEpsg.
    function doAfterAddAction(x, y, crsEpsg) {
        if (appSettings.afterAddAction === 1) {
            var sourceCrs = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + crsEpsg)
            var pt = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs,
                                                  mapCanvas.mapSettings.destinationCrs)
            mapCanvas.mapSettings.setCenter(pt, true)
        } else if (appSettings.afterAddAction === 2) {
            zoomToPoint(x, y, crsEpsg)
        }
        // 0 = do nothing
    }

function handlePaste(clipboardText, createPointAndZoom, alwaysZoom) {
    if (alwaysZoom === undefined) alwaysZoom = false;
    if (clipboardText === undefined || clipboardText === null)
        clipboardText = Qt.application.clipboard.text;

    let raw = (clipboardText || "").trim();
    // Compact (no spaces) for grid-ref matching
    let compact = raw.replace(/\s+/g, '').substring(0, 200);

    // --- Grid reference helpers ---
    function padGridNumbers(numbers) {
        // Accept 2, 4, 6, 8 or 10 digits (equal easting/northing halves)
        var len = numbers.length;
        if (len < 2 || len > 10 || len % 2 !== 0) return null;
        var half = len / 2;
        var e = numbers.substring(0, half);
        var n = numbers.substring(half);
        while (e.length < 5) e += '0';
        while (n.length < 5) n += '0';
        return e + ' ' + n;
    }

    // --- Universal single-coordinate parser ---
    // Accepts a string representing one lat or lon value in any of:
    //   Decimal degrees:      "53.3498"  or  "-53.3498"
    //   Degrees decimal mins: "53 20.988"  or  "53° 20.988'"  or  "N53 20.988"
    //   DMS:                  "53 20 59.28"  or  "53° 20' 59.28\"N"
    // (call after normalising °'" to spaces)
    // Returns decimal degrees, or null if unparseable.
    function parseCoordPart(s) {
        s = s.trim();
        // Pull off a leading hemisphere letter (N/S/E/W)
        let hemi = '';
        let hLead = s.match(/^([NSEWnsew])\s*/);
        if (hLead) { hemi = hLead[1].toUpperCase(); s = s.substring(hLead[0].length).trim(); }
        // Pull off a trailing hemisphere letter
        let hTrail = s.match(/\s*([NSEWnsew])$/);
        if (hTrail) { hemi = hTrail[1].toUpperCase(); s = s.substring(0, s.length - hTrail[0].length).trim(); }

        let parts = s.split(/\s+/).map(Number);
        if (parts.length === 0 || parts.length > 3 || parts.some(isNaN)) return null;

        let decimal = Math.abs(parts[0]);
        if (parts.length >= 2) decimal += parts[1] / 60;
        if (parts.length >= 3) decimal += parts[2] / 3600;

        // Apply sign: explicit negative degree OR S/W hemisphere
        if (parts[0] < 0 || hemi === 'S' || hemi === 'W') decimal = -decimal;
        return decimal;
    }

    // Helper: open the format dialog with pre-filled values
    function showFormatDialog(displayText, a, b, formatIdx) {
        pasteFormatDialog.rawText = displayText;
        pasteFormatDialog.parsedA = a;
        pasteFormatDialog.parsedB = b;
        pasteFormatDialog.parsedZ = NaN;   // no Z for non-WKT pastes
        pasteFormatDialog.defaultFormatIndex = formatIdx;
        pasteFormatDialog.createPointOnSuccess = createPointAndZoom;
        pasteFormatDialog.alwaysZoom = alwaysZoom;
        pendingAlwaysZoom = alwaysZoom;
        pasteFormatDialog.open();
    }

    // ── 0a. geo: URI (from QR code scan or manual paste) ─────────────────
    // Formats: geo:lat,lon  or  geo:lat,lon,alt  (altitude ignored)
    var geoMatch = raw.match(/^geo:([-\d.]+),([-\d.]+)(?:,([-\d.]+))?/i)
    if (geoMatch) {
        var gLat = parseFloat(geoMatch[1])
        var gLon = parseFloat(geoMatch[2])
        if (!isNaN(gLat) && !isNaN(gLon)) {
            updateCoordinates(gLon, gLat, 4326, custom1CRS.text, custom2CRS.text)
            if (createPointAndZoom) {
                addPoint(gLon, gLat, 4326)
                Qt.callLater(function() { alwaysZoom ? zoomToPoint(gLon, gLat, 4326) : doAfterAddAction(gLon, gLat, 4326) })
            }
            return true
        }
    }

    // ── 0b. WKT Point (POINT / POINT Z / POINT M / POINT ZM) ──────────────
    var wktMatch = raw.match(/Point\s*(ZM|Z|M)?\s*\(\s*([-\d.]+)\s+([-\d.]+)(?:\s+([-\d.]+))?(?:\s+([-\d.]+))?\s*\)/i)
    if (wktMatch) {
        var wktType = (wktMatch[1] || "").toUpperCase()  // "", "Z", "M", or "ZM"
        var wktX = parseFloat(wktMatch[2])
        var wktY = parseFloat(wktMatch[3])
        var wktVal3 = wktMatch[4] !== undefined ? parseFloat(wktMatch[4]) : NaN
        var wktVal4 = wktMatch[5] !== undefined ? parseFloat(wktMatch[5]) : NaN
        // Z is the 3rd value when type is Z or ZM; absent for plain POINT or POINT M
        var wktHasZ = (wktType === "Z" || wktType === "ZM") && !isNaN(wktVal3)
        var wktZ    = wktHasZ ? wktVal3 : NaN
        if (!isNaN(wktX) && !isNaN(wktY)) {
            wktCrsDialog.pendingX    = wktX
            wktCrsDialog.pendingY    = wktY
            wktCrsDialog.pendingZ    = wktHasZ ? wktZ : 0
            wktCrsDialog.pendingHasZ = wktHasZ
            wktCrsDialog.createPointOnSuccess = createPointAndZoom
            wktCrsDialog.alwaysZoom  = alwaysZoom
            wktCrsDialog.open()
            return true
        }
    }

    // ── 0a. MGRS ──────────────────────────────────────────────────────────
    var mgrsClean = raw.replace(/\s+/g, '').toUpperCase()
    // MGRS pattern: 1-2 digits, 3 letters, even digit count 0-10
    if (/^\d{0,2}[A-Z]{3}\d{0,10}$/.test(mgrsClean) && mgrsClean.length >= 3) {
        var mgrsLL = mgrsToLatLon(mgrsClean)
        if (mgrsLL !== null) {
            var mgrsDisp = "MGRS: " + raw.trim() + "  (giving " + mgrsLL.lat.toFixed(5) + ", " + mgrsLL.lon.toFixed(5) + ")"
            showFormatDialog(mgrsDisp, mgrsLL.lat, mgrsLL.lon, 0)
            return true
        }
    }

    // ── 0b. Plus Code ─────────────────────────────────────────────────────
    var olcTest = raw.trim().toUpperCase()
    if (OLC.isFull(olcTest)) {
        var olcDec = OLC.decode(olcTest)
        if (olcDec !== null) {
            var olcDisp = "Plus Code: " + raw.trim() + "  (giving " + olcDec.latitudeCenter.toFixed(5) + ", " + olcDec.longitudeCenter.toFixed(5) + ")"
            showFormatDialog(olcDisp, olcDec.latitudeCenter, olcDec.longitudeCenter, 0)
            return true
        }
    }

    // ── 1. UK Grid: two letters + 2/4/6/8/10 digits ─────────────────────
    if (/^[A-Z]{2}\d{2,10}$/i.test(compact) && compact.substring(2).length % 2 === 0) {
        let letters = compact.substring(0,2).toUpperCase();
        let padded  = padGridNumbers(compact.substring(2));
        let entry   = ukletterMatrix[letters];
        if (entry && padded) {
            let easting  = parseInt(padded.substring(0,5)) + (entry.first  * 100000);
            let northing = parseInt(padded.substring(6))   + (entry.second * 100000);
            showFormatDialog(`${letters} ${padded}`, easting, northing, 3);
            return true;
        }
    }
    // ── 2. Irish Grid: one letter + 2/4/6/8/10 digits ───────────────────
    else if (/^[A-Z]\d{2,10}$/i.test(compact) && compact.substring(1).length % 2 === 0) {
        let letter = compact.substring(0,1).toUpperCase();
        let padded = padGridNumbers(compact.substring(1));
        let entry  = igletterMatrix[letter];
        if (entry && padded) {
            let easting  = parseInt(padded.substring(0,5)) + (entry.first  * 100000);
            let northing = parseInt(padded.substring(6))   + (entry.second * 100000);
            showFormatDialog(`${letter} ${padded}`, easting, northing, 2);
            return true;
        }
    }
    // ── 3. Degree-based formats: DMS / DDM / decimal / projected ─────────
    else {
        // Normalise degree/minute/second symbols to plain spaces,
        // then split on the comma that separates the two coordinates.
        let norm = raw.replace(/°/g, ' ').replace(/'/g, ' ').replace(/"/g, ' ')
                      .replace(/\s+/g, ' ').trim();

        // DMS/hemisphere markers mean it's clearly lat/lon; plain decimals are ambiguous.
        let hasDmsHemi = /[°'"NSEWnsew]/.test(raw);

        let commaIdx = norm.indexOf(',');
        if (commaIdx > 0) {
            let a = parseCoordPart(norm.substring(0, commaIdx));
            let b = parseCoordPart(norm.substring(commaIdx + 1));
            if (a !== null && b !== null) {
                let defIdx = (hasDmsHemi || (Math.abs(a) <= 90 && Math.abs(b) <= 180)) ? 0 : 4;
                showFormatDialog(raw, a, b, defIdx);
                return true;
            }
        }

        // Plain space-separated decimal pair — e.g. "53.3498 -6.2603"
        let sp = raw.trim().split(/\s+/);
        if (sp.length === 2) {
            let a = parseFloat(sp[0]), b = parseFloat(sp[1]);
            if (!isNaN(a) && !isNaN(b)) {
                let defIdx = (hasDmsHemi || (Math.abs(a) <= 90 && Math.abs(b) <= 180)) ? 0 : 4;
                showFormatDialog(raw, a, b, defIdx);
                return true;
            }
        }
    }

    // ── Fallback: let the user edit and retry ─────────────────────────────
    pasteErrDialog.clipboardText = raw.length > 200 ? raw.substring(0, 200) : raw;
    pasteErrDialog.hintText = diagnosePasteError(raw);
    pasteErrDialog.createPointOnSuccess = createPointAndZoom;
    pasteErrDialog.open();
    return false;
}

// Analyses a failed paste string and returns a user-friendly hint.
function diagnosePasteError(raw) {
    if (!raw || raw.trim().length === 0)
        return qsTr("The clipboard appears to be empty.");

    let c = raw.replace(/\s+/g, '');

    // URL
    if (/^https?:\/\//i.test(raw.trim()))
        return qsTr("This looks like a URL. Copy just the coordinate numbers instead, e.g. \"53.3498, -6.2603\".");

    // Looks like Irish Grid (1 letter + digits) — check digit count and letter validity
    let igLike = c.match(/^([A-Za-z])(\d+)$/);
    if (igLike) {
        let letter = igLike[1].toUpperCase();
        let digits = igLike[2];
        if (digits.length % 2 !== 0)
            return qsTr("Looks like an Irish Grid ref but has an odd number of digits (%1) — needs an even count of 2–10 (e.g. O 159 343 or O 15930 34300).").arg(digits.length);
        if (digits.length > 10)
            return qsTr("Looks like an Irish Grid ref but has %1 digits — maximum is 10 (e.g. O 15930 34300).").arg(digits.length);
        if (!igletterMatrix[letter])
            return qsTr("'%1' is not a valid Irish Grid square. Valid letters: A–E, F–H, J–K, L–P, Q–T, V–Z (I and U are not used).").arg(letter);
    }

    // Looks like UK Grid (2 letters + digits) — check digit count and square validity
    let ukLike = c.match(/^([A-Za-z]{2})(\d+)$/);
    if (ukLike) {
        let letters = ukLike[1].toUpperCase();
        let digits = ukLike[2];
        if (digits.length % 2 !== 0)
            return qsTr("Looks like a UK Grid ref but has an odd number of digits (%1) — needs an even count of 2–10 (e.g. NS 451 728 or NS 45140 72887).").arg(digits.length);
        if (digits.length > 10)
            return qsTr("Looks like a UK Grid ref but has %1 digits — maximum is 10 (e.g. NS 45140 72887).").arg(digits.length);
        if (!ukletterMatrix[letters])
            return qsTr("'%1' is not a recognised UK Grid square.").arg(letters);
    }

    // Has a comma but couldn't parse — likely extra text around the numbers
    if (raw.indexOf(',') !== -1)
        return qsTr("A comma was found but the values couldn't be parsed. Remove any labels such as \"lat:\", \"lon:\", or \"easting:\" and paste just the numbers.");

    // Only one number
    let sp = raw.trim().split(/\s+/);
    if (sp.length === 1 && !isNaN(parseFloat(sp[0])))
        return qsTr("Only one number found. Two values are needed — paste easting + northing, or latitude + longitude, separated by a comma or space.");

    // Lots of text — probably copied more than just the coordinate
    if (raw.length > 40)
        return qsTr("Too much text to parse. Select and copy just the coordinate part and try again.");

    return qsTr("The text could not be recognised as a coordinate. Edit it to match one of the examples below.");
}

// ── QR Code dialog — shows geo: URI as scannable QR code ─────────────────────
Dialog {
    id: qrDialog
    property string geoUri: ""
    parent: mainWindow.contentItem
    title: qsTr("QR Code")
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(parent.width - 40, 300)
    modal: true
    standardButtons: Dialog.Close

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        topPadding: 6

        Image {
            id: qrImage
            property int sz: Math.min(qrDialog.width - 40, 240)
            width: sz; height: sz
            sourceSize.width: sz; sourceSize.height: sz
            source: qrDialog.geoUri !== "" ? "image://barcode/?text=" + encodeURIComponent(qrDialog.geoUri) : ""
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            width: qrDialog.width - 40
            text: qrDialog.geoUri
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
            color: palette.text
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Button {
                text: qsTr("Copy URI")
                font.pixelSize: 12
                font.bold: true
                width: (qrDialog.width - 48) / 2
                height: 36
                background: Rectangle { color: "#B3EBF2"; radius: 8 }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#333333"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: copyToClipboard(qrDialog.geoUri)
            }

            Button {
                text: qsTr("Share Image")
                font.pixelSize: 12
                font.bold: true
                width: (qrDialog.width - 48) / 2
                height: 36
                background: Rectangle { color: "#B3EBF2"; radius: 8 }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#333333"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var path = StandardPaths.writableLocation(StandardPaths.TempLocation) + "/qr_geo.png"
                    qrImage.grabToImage(function(result) {
                        if (result.saveToFile(path)) {
                            Qt.openUrlExternally("file://" + path)
                        } else {
                            mainWindow.displayToast(qsTr("Could not save QR image"))
                        }
                    })
                }
            }
        }
    }
}

// Forward accepted scan results through handlePaste when triggered by Scan QR button
Connections {
    target: codeReader
    function onAccepted(string) {
        if (_qrScanPending) {
            _qrScanPending = false
            handlePaste(string)
        }
    }
}

Dialog {
    id: pasteErrDialog
    parent: mainWindow.contentItem
    visible: false
    modal: true
    width: 350
    font: Theme.defaultFont
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) * 0.15

    property string clipboardText: ""
    property string hintText: ""
    property bool createPointOnSuccess: false

    title: qsTr("Paste Error")
    standardButtons: Dialog.Ok | Dialog.Cancel
    closePolicy: Dialog.NoAutoClose

    onOpened: {
        editablePasteContent.text = clipboardText;
        standardButton(Dialog.Ok).text = qsTr("Try Again");
        editablePasteContent.forceActiveFocus();
    }

    onAccepted: {
        let edited = editablePasteContent.text || "";
        if (edited.length > 100)
            edited = edited.substring(0, 100);

        // Delay the re-check until after the dialog closes
        Qt.callLater(function() {
            handlePaste(edited, createPointOnSuccess);
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Dynamic hint explaining why parsing failed
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.bold: true
            color: "#cc0000"
            text: pasteErrDialog.hintText
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Edit the text below and tap Try Again:")
        }

        TextArea {
            id: editablePasteContent
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            wrapMode: Text.Wrap
            placeholderText: "Pasted content"
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            text: "<b>Valid formats:</b><br>" +
                  "<b>Irish Grid</b> — 1 letter + 10 digits<br>" +
                  "&#160;&#160;O 15930 34300 &#160;or&#160; O1593034300<br>" +
                  "<b>UK Grid</b> — 2 letters + 10 digits<br>" +
                  "&#160;&#160;NS 45140 72887 &#160;or&#160; NS4514072887<br>" +
                  "<b>Decimal degrees</b> — lat, lon<br>" +
                  "&#160;&#160;53.3498, -6.2603<br>" +
                  "<b>With hemisphere</b><br>" +
                  "&#160;&#160;N53.3498, W6.2603<br>" +
                  "<b>Degrees minutes</b><br>" +
                  "&#160;&#160;53° 20.988' N, 6° 15.619' W<br>" +
                  "<b>Degrees minutes seconds</b><br>" +
                  "&#160;&#160;53° 20' 59\" N, 6° 15' 37\" W"
        }
    }
}

// ── Format disambiguation dialog ──────────────────────────────────────────
// Shown when a plain decimal pair is pasted and the CRS is uncertain.
Dialog {
    id: pasteFormatDialog
    parent: mainWindow.contentItem
    visible: false
    modal: true
    width: 350
    font: Theme.defaultFont
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) * 0.15

    property string rawText: ""
    property real   parsedA: 0
    property real   parsedB: 0
    property real   parsedZ: NaN
    property int    defaultFormatIndex: 0
    property bool   createPointOnSuccess: false
    property bool   alwaysZoom: false

    title: qsTr("Confirm coordinate format")
    standardButtons: Dialog.Ok | Dialog.Cancel

    onOpened: {
        formatEpsgInput.text = canvasEPSG
        formatCombo.currentIndex = defaultFormatIndex
        formatCoordEdit.text = rawText
        standardButton(Dialog.Ok).text = qsTr("Apply")
    }

    onAccepted: {
        let edited = formatCoordEdit.text.trim()
        let textChanged  = (edited !== rawText.trim())
        let formatChanged = (formatCombo.currentIndex !== defaultFormatIndex)

        // Re-run the parser when:
        //  a) the user edited the text, OR
        //  b) the original input was a grid ref (parsedA/B are computed metre values,
        //     not raw numbers — reusing them under a different format gives garbage)
        if (textChanged || (formatChanged && (defaultFormatIndex === 2 || defaultFormatIndex === 3))) {
            let _zoom = pendingAlwaysZoom
            Qt.callLater(function() {
                handlePaste(edited, createPointOnSuccess, _zoom)
            })
            return
        }

        // Text unchanged, and either format unchanged or input was a decimal pair
        // (parsedA/B are raw numbers safe to reuse under a different format) —
        // apply using the pre-parsed values and selected format
        var idx = formatCombo.currentIndex
        var px, py, pcrs, disp
        if (idx === 0) {          // WGS84 lat, lon
            py = parsedA; px = parsedB; pcrs = 4326
            disp = rawText.trim() + " — WGS84 lat, lon"
            updateCoordinates(px, py, 4326, custom1CRS.text, custom2CRS.text, 5)
        } else if (idx === 1) {   // WGS84 lon, lat
            px = parsedA; py = parsedB; pcrs = 4326
            disp = rawText.trim() + " — WGS84 lon, lat"
            updateCoordinates(px, py, 4326, custom1CRS.text, custom2CRS.text, 5)
        } else if (idx === 2) {   // Irish Grid
            px = parsedA; py = parsedB; pcrs = 29903
            disp = rawText.trim() + " — Irish Grid"
            updateCoordinates(px, py, 29903, custom1CRS.text, custom2CRS.text)
        } else if (idx === 3) {   // UK Grid
            px = parsedA; py = parsedB; pcrs = 27700
            disp = rawText.trim() + " — UK Grid"
            updateCoordinates(px, py, 27700, custom1CRS.text, custom2CRS.text)
        } else {                  // Custom EPSG X, Y
            var epsg = parseInt(formatEpsgInput.text) || canvasEPSG
            px = parsedA; py = parsedB; pcrs = epsg
            disp = rawText.trim() + " (EPSG:" + epsg + ")"
            updateCoordinates(px, py, epsg, custom1CRS.text, custom2CRS.text)
        }
        if (createPointOnSuccess) {
            addPoint(px, py, pcrs, isNaN(parsedZ) ? undefined : parsedZ)
            let _ax = px, _ay = py, _acrs = pcrs, _az = pendingAlwaysZoom
            Qt.callLater(function() {
                if (_az)
                    zoomToPoint(_ax, _ay, _acrs)
                else
                    doAfterAddAction(_ax, _ay, _acrs)
            })
        }
        mainWindow.displayToast(qsTr("Loaded: ") + disp)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Confirm or edit the coordinate, then select its format:")
        }

        TextArea {
            id: formatCoordEdit
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            wrapMode: Text.Wrap
        }

        ComboBox {
            id: formatCombo
            Layout.fillWidth: true
            model: [
                qsTr("WGS84  —  lat, lon  (first value is latitude)"),
                qsTr("WGS84  —  lon, lat  (first value is longitude)"),
                qsTr("Irish Grid  (EPSG:29903)"),
                qsTr("UK Grid  (EPSG:27700)"),
                qsTr("Custom EPSG  —  X, Y")
            ]
        }

        RowLayout {
            visible: formatCombo.currentIndex === 4
            Layout.fillWidth: true
            Label { text: qsTr("EPSG:") }
            TextField {
                id: formatEpsgInput
                Layout.fillWidth: true
                validator: IntValidator { bottom: 1; top: 999999 }
                placeholderText: "e.g. 29903"
            }
        }
    }
}






MenuItem{ 
    id: addPointButton
    text: qsTr("Add point")
    icon.source: 'plugin_stuff/new.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont
    onClicked: {
        addPointToActiveLayer(
            GeometryUtils.createGeometryFromWkt(`POINT(${canvasMenu.point.x} ${canvasMenu.point.y})`),
            formOnAdd);
        doAfterAddAction(canvasMenu.point.x, canvasMenu.point.y, canvasEPSG);
    }
}

MenuItem {
    id: navButton
    text: qsTr("Open externally")
    icon.source: 'plugin_stuff/car.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont

    onClicked: {
        var transformedPoint = GeometryUtils.reprojectPoint(
            GeometryUtils.point(canvasMenu.point.x, canvasMenu.point.y),
            mapCanvas.mapSettings.destinationCrs,
            CoordinateReferenceSystemUtils.fromDescription("EPSG:4326")
        )
        Qt.openUrlExternally(buildMapsUrl(transformedPoint.y, transformedPoint.x))
    }

}

MenuItem {
    id: convertButton
    text: qsTr("Convert/Show coordinates")
    icon.source: 'plugin_stuff/spir.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont

    onClicked: {
        
        // open main Dialog
        mainDialog.open()
        // Get coordinates from canvas position and put them into the mian Dialog
        updateCoordinates(canvasMenu.point.x, canvasMenu.point.y, canvasEPSG, custom1CRS.text, custom2CRS.text)
              
    }
 }



MenuItem {
    id: pasteButton
    text: qsTr("Paste location from clipboard")
    icon.source: 'plugin_stuff/paste.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont

    onClicked: {
        // Create temporary TextEdit for clipboard access
        let clipboard = Qt.createQmlObject('import QtQuick; TextEdit { visible: false }', plugin)
        clipboard.paste()
        let clipboardText = clipboard.text;
        clipboard.destroy()

        handlePaste(clipboardText, true, true);
    }
}







// Irish Grid/ UK Grid Locator Filter
QFieldLocatorFilter {
    id: igukGridsFilter2
    delay: 1000
    name: "IG & UK Grids"
    displayName: "IG & UK Grid finder"
    prefix: "grid"
    locatorBridge: iface.findItemByObjectName('locatorBridge')
    source: Qt.resolvedUrl('plugin_stuff/grids.qml')
    

function triggerResult(result) {
  if (result.userData && result.userData.geometry) {
    const geometry = result.userData.geometry;
    const crs = CoordinateReferenceSystemUtils.fromDescription(result.userData.crs);

    // Reproject the geometry to the map's CRS
    const reprojectedGeometry = GeometryUtils.reprojectPoint(
      geometry,
      crs,
      mapCanvas.mapSettings.destinationCrs
    );

    // Center the map on the reprojected geometry
   mapCanvas.mapSettings.setCenter(reprojectedGeometry, true);

    // Highlight the geometry on the map
    locatorBridge.locatorHighlightGeometry.qgsGeometry = geometry;
    locatorBridge.locatorHighlightGeometry.crs = crs;
  } else {
    mainWindow.displayToast("Invalid geometry in result");
  }
}
function triggerResultFromAction(result, actionId) {
  if (result.userData && result.userData.geometry) {
    const geometry = result.userData.geometry;
    const crs = CoordinateReferenceSystemUtils.fromDescription(result.userData.crs);

    // Reproject the geometry to the map's CRS
    const reprojectedPoint = GeometryUtils.reprojectPoint(
      geometry,
      crs,
      mapCanvas.mapSettings.destinationCrs
    );

    if (actionId === 1) {
      // Set the navigation destination
      const navigation = iface.findItemByObjectName('navigation');
      if (navigation) {
        navigation.destination = reprojectedPoint;
        mainWindow.displayToast("Destination set successfully");
      } else {
        mainWindow.displayToast("Navigation component not found");
      }

    } else if (actionId === 2) {
        addPointToActiveLayer(
            GeometryUtils.createGeometryFromWkt(`POINT(${reprojectedPoint.x} ${reprojectedPoint.y})`),
            formOnAdd);
        doAfterAddAction(reprojectedPoint.x, reprojectedPoint.y, canvasEPSG);
    }
  } else {
    mainWindow.displayToast("Invalid action or geometry");
  }
  
}
}   




//small crosshair
Rectangle {
    id: crosshair
    visible: true
    parent: iface.mapCanvas()
    color: "transparent"
    width: 40
    height: 40
    anchors.centerIn: parent

    property int gap: 10          // size of transparent center hole (adjust 8–14)
    property int lineW: 5         // total line thickness (keeps it odd → perfect centering)

    // ── Horizontal left arm
    Rectangle {
        width: (parent.width - parent.gap) / 2
        height: parent.lineW
        color: "transparent"
        anchors {
            right: parent.horizontalCenter
            rightMargin: parent.gap / 2
            verticalCenter: parent.verticalCenter
        }

        // White bottom part
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.bottom: parent.bottom }
        // Black core – exactly centered vertically
        Rectangle { width: parent.width; height: 2; color: "black"; anchors.centerIn: parent }
        // White top part
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.top: parent.top }
    }

    // ── Horizontal right arm (identical)
    Rectangle {
        width: (parent.width - parent.gap) / 2
        height: parent.lineW
        color: "transparent"
        anchors {
            left: parent.horizontalCenter
            leftMargin: parent.gap / 2
            verticalCenter: parent.verticalCenter
        }
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.bottom: parent.bottom }
        Rectangle { width: parent.width; height: 2;   color: "black";  anchors.centerIn: parent }
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.top:    parent.top }
    }

    // ── Vertical top arm
    Rectangle {
        width: parent.lineW
        height: (parent.height - parent.gap) / 2
        color: "transparent"
        anchors {
            bottom: parent.verticalCenter
            bottomMargin: parent.gap / 2
            horizontalCenter: parent.horizontalCenter
        }

        // White right part
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.right: parent.right }
        // Black core – exactly centered horizontally
        Rectangle { width: 2;   height: parent.height; color: "black";  anchors.centerIn: parent }
        // White left part
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.left:  parent.left }
    }

    // ── Vertical bottom arm (identical)
    Rectangle {
        width: parent.lineW
        height: (parent.height - parent.gap) / 2
        color: "transparent"
        anchors {
            top: parent.verticalCenter
            topMargin: parent.gap / 2
            horizontalCenter: parent.horizontalCenter
        }
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.right: parent.right }
        Rectangle { width: 2;   height: parent.height; color: "black";  anchors.centerIn: parent }
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.left:  parent.left }
    }

    // Optional tiny center ring (many people love this for vertex snapping)
    // Rectangle {
     //    width: 10; height: 10; radius: 5
    //     color: "transparent"
    //    border.color: "#ccffffff"
    //     border.width: 1
    //     anchors.centerIn: parent
   //  }
}

QfToolButton {
 id: mainPluginButton
 bgcolor: Theme.darkGray
 iconSource: 'icon2.svg'
 round: true
 onClicked: mainDialog.open()
 onPressAndHold: settingsDialog.open()
}
 



// ── WKT CRS picker ───────────────────────────────────────────────────────
Dialog {
    id: wktCrsDialog
    parent: mainWindow.contentItem
    visible: false
    modal: true
    width: 350
    font: Theme.defaultFont
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) * 0.15

    property real   pendingX:    0
    property real   pendingY:    0
    property real   pendingZ:    0
    property bool   pendingHasZ: false
    property bool   createPointOnSuccess: false
    property bool   alwaysZoom: false

    title: qsTr("WKT Point — select CRS")
    standardButtons: Dialog.Ok | Dialog.Cancel

    onOpened: {
        wktCrsModel.clear()
        var projCrs = mapCanvas.mapSettings.destinationCrs
        wktCrsModel.append({ label: "Project CRS  (" + projCrs.authid + ")", authid: projCrs.authid })
        if (dashBoard.activeLayer) {
            var lCrs = dashBoard.activeLayer.crs
            if (lCrs && lCrs.authid !== projCrs.authid)
                wktCrsModel.append({ label: "Layer CRS  (" + lCrs.authid + ")", authid: lCrs.authid })
        }
        if (custom1CRS.text)
            wktCrsModel.append({ label: "Custom 1  (EPSG:" + custom1CRS.text + ")", authid: "EPSG:" + custom1CRS.text })
        if (custom2CRS.text)
            wktCrsModel.append({ label: "Custom 2  (EPSG:" + custom2CRS.text + ")", authid: "EPSG:" + custom2CRS.text })
        wktCrsCombo.currentIndex = 0
    }

    onAccepted: {
        var item = wktCrsModel.get(wktCrsCombo.currentIndex)
        var fromCrs = CoordinateReferenceSystemUtils.fromDescription(item.authid)
        var wgs84Crs = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326")
        var pt = GeometryUtils.reprojectPoint(GeometryUtils.point(pendingX, pendingY), fromCrs, wgs84Crs)
        if (!pt || isNaN(pt.y) || isNaN(pt.x)) {
            mainWindow.displayToast(qsTr("Could not reproject point — check CRS selection"))
            return
        }
        // CRS already resolved — update displays and optionally add point directly
        updateCoordinates(pendingX, pendingY,
            parseInt(item.authid.replace("EPSG:","")) || 4326,
            custom1CRS.text, custom2CRS.text)
        if (createPointOnSuccess) {
            var z = pendingHasZ ? pendingZ : undefined
            addPoint(pendingX, pendingY,
                parseInt(item.authid.replace("EPSG:","")) || 4326, z)
            var _ax = pendingX, _ay = pendingY
            var _acrs = parseInt(item.authid.replace("EPSG:","")) || 4326
            var _az = alwaysZoom
            pendingAlwaysZoom = alwaysZoom
            Qt.callLater(function() {
                if (_az) zoomToPoint(_ax, _ay, _acrs)
                else     doAfterAddAction(_ax, _ay, _acrs)
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.bold: true
            text: "X: " + wktCrsDialog.pendingX.toFixed(3) + "   Y: " + wktCrsDialog.pendingY.toFixed(3)
                  + (wktCrsDialog.pendingHasZ ? "   Z: " + wktCrsDialog.pendingZ.toFixed(3) : "")
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Which CRS are these coordinates in?")
        }

        ComboBox {
            id: wktCrsCombo
            Layout.fillWidth: true
            model: ListModel { id: wktCrsModel }
            textRole: "label"
        }
    }
}

Dialog {
 id: mainDialog
 parent: mainWindow.contentItem
 visible: false
 modal: true
 font: Theme.defaultFont
 Layout.preferredHeight: 35
 width: 380


 x: (mainWindow.width - width) / 2
 y: (mainWindow.height - height) * 0.15

 ColumnLayout {
 anchors.fill: parent
 anchors.margins : 1



RowLayout{
 Layout.fillWidth: true
 Label {
 id: label_1
 visible: true
 font.bold: true
 wrapMode: Text.Wrap
 text: qsTr("Grab:")
 font.pixelSize: font_Size.text
 font.family: "Arial" // Set font family
 font.italic: true // Make text italic
 } 

Button {
 text: qsTr("Screencenter")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 Layout.preferredHeight: 35 
 onClicked: {
 var pos = canvas.center
 updateCoordinates(pos.x, pos.y, canvasEPSG, custom1CRS.text, custom2CRS.text)
 } 
 } 

 
 Button {
 text: qsTr("GPS")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 Layout.preferredHeight: 35 

 onClicked: {
 if (!positionSource.active || !positionSource.positionInformation.latitudeValid || !positionSource.positionInformation.longitudeValid) {
 mainWindow.displayToast(qsTr("GPS must be active"))} else 
 { 
 var pos = positionSource.projectedPosition
 updateCoordinates(pos.x, pos.y, canvasEPSG, custom1CRS.text, custom2CRS.text) 
 }
 }
 }
     Button {
        text: "⚙"
        font.pixelSize: 18
        Layout.preferredHeight: 32
        Layout.preferredWidth: 32
        onClicked: settingsDialog.open()
        contentItem: Text {
            text: "⚙"
            font.pixelSize: 18
            color: "#000000"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
Button {
 text: qsTr("Paste from clipboard")
 font.bold: true
 Layout.fillWidth: true
 visible: true
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 Layout.preferredHeight: 35 
 onClicked: {

    // Create temporary TextEdit for clipboard access
    let clipboard = Qt.createQmlObject('import QtQuick; TextEdit { visible: false }', plugin)
    clipboard.paste();
    let clipboardText = clipboard.text;
    clipboard.destroy();

    handlePaste(clipboardText, false);
 } 
 } 

ColumnLayout{
visible: true 
//spacing: 1

// Irish Grid
RowLayout{
    id: igridrow
    visible: igvis

TextField {
 id: igInputBox //1
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.bold: true
 font.italic: true
 Layout.fillWidth: true
 placeholderText: "Irish Grid: X 00000 00000"
 property bool isProgrammaticUpdate: false
 property bool hasError: false
 color: hasError ? "#cc0000" : palette.text
 onTextChanged: {
    if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return }
    hasError = false
    lastEditedBox = "ig"; coordinatesDirty = true
    formatGridInput(igInputBox, igletterMatrix, 1)
 }

 // Accept L dN dN where N is 1–5 and both groups have equal digit count
 function isValidInput() {
     var m = igInputBox.text.match(/^([A-Za-z])\s(\d{1,5})\s(\d{1,5})$/)
     return m && m[2].length === m[3].length && igletterMatrix[m[1].toUpperCase()]
 }
}


Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: copyIG  
    font.bold: true
    width: 10
    height: 10

    background: Rectangle {
        color: "#B3EBF2" 
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(igInputBox.text)
    }
}
} 
// UK Grid 
 
RowLayout{
    id:ukgridrow 
    visible: ukgvis

TextField {
 id: ukInputBox //2
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.bold: true
 font.italic: true 
 Layout.fillWidth: true
 placeholderText: "UK Grid: XX 00000 00000"
 
 // Flag to indicate programmatic updates
 property bool isProgrammaticUpdate: false
 property bool hasError: false
 color: hasError ? "#cc0000" : palette.text
 onTextChanged: {
    if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return }
    hasError = false
    lastEditedBox = "uk"; coordinatesDirty = true
    formatGridInput(ukInputBox, ukletterMatrix, 2)
 }

 // Accept LL dN dN where N is 1–5 and both groups have equal digit count
 function isValidInput() {
     var m = ukInputBox.text.match(/^([A-Za-z]{2})\s(\d{1,5})\s(\d{1,5})$/)
     return m && m[2].length === m[3].length && ukletterMatrix[m[1].toUpperCase()]
 }
}
Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: copyUK  
    //visible: false
    font.bold: true
    width: 10
    height: 10
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(ukInputBox.text)
    }
}
} 
 
// MGRS Row
RowLayout {
    id: mgrsrow
    visible: mgrsvis

TextField {
    id: mgrsBox
    Layout.fillWidth: true
    Layout.preferredHeight: 35
    font.pixelSize: font_Size.text
    font.family: "Arial"
    font.bold: true
    font.italic: true
    placeholderText: "MGRS: 30U WB 45140 72887"
    property bool isProgrammaticUpdate: false
    property bool hasError: false
    color: hasError ? "#cc0000" : palette.text
    onTextChanged: {
        if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return }
        hasError = false
        lastEditedBox = "mgrs"; coordinatesDirty = true
    }
}
Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18; icon.height: 18
    font.bold: true
    width: 10; height: 10
    background: Rectangle { color: "#B3EBF2"; radius: width / 2 }
    onClicked: { ensureConverted(); copyToClipboard(mgrsBox.text) }
}
}

// Plus Code Row
RowLayout {
    id: pluscoderow
    visible: pluscodevis

TextField {
    id: pluscodeBox
    Layout.fillWidth: true
    Layout.preferredHeight: 35
    font.pixelSize: font_Size.text
    font.family: "Arial"
    font.bold: true
    font.italic: true
    placeholderText: "Plus Code: 9C3X2222+22"
    property bool isProgrammaticUpdate: false
    property bool hasError: false
    color: hasError ? "#cc0000" : palette.text
    onTextChanged: {
        if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return }
        hasError = false
        lastEditedBox = "pluscode"; coordinatesDirty = true
    }
}
Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18; icon.height: 18
    font.bold: true
    width: 10; height: 10
    background: Rectangle { color: "#B3EBF2"; radius: width / 2 }
    onClicked: { ensureConverted(); copyToClipboard(pluscodeBox.text) }
}
}

// Custom1 Row
RowLayout {
    id: custom1row
    visible: custom1vis

TextField {
    id: custom1BoxXY //3
    property bool isProgrammaticUpdate: false
    property bool hasError: false
    color: hasError ? "#cc0000" : palette.text
    Layout.preferredHeight: 35
    Layout.preferredWidth: 180
    font.pixelSize: font_Size.text
    font.family: "Arial"
    font.bold: true
    font.italic: true
    placeholderText: crsIsGeographic(custom1CRS.text) ? "Lat, Long" : "X, Y"
    //visible: false
    text: ""

    onTextChanged: {
        if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return; }
        lastEditedBox = "custom1"; coordinatesDirty = true;
    }
}

//end of custombox1 


 CrsPicker {
 id: custom1CRS
 Layout.fillWidth: true
 fieldFontSize: font_Size.text
 text: appSettings.crs1 !== "" ? appSettings.crs1 : String(canvasEPSG)
 placeholderText: " EPSG"
 onTextChanged: {
     appSettings.crs1 = text
     var parts = wgs84Box.text.split(',').map(function(p) { return parseFloat(p.trim()) })
     if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1]))
         updateCoordinates(parts[1], parts[0], 4326, custom1CRS.text, custom2CRS.text)
 }
 }
 Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: custom1copy
    font.bold: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(custom1BoxXY.text)
    }
}

 }
 
// custom2
RowLayout {
 id: custom2row
 visible: custom2vis



TextField {
    id: custom2BoxXY
    property bool isProgrammaticUpdate: false
    property bool hasError: false
    color: hasError ? "#cc0000" : palette.text
    Layout.preferredWidth: 180
    Layout.preferredHeight: 35
    font.pixelSize: font_Size.text
    font.family: "Arial"
    font.italic: true
    font.bold: true
    placeholderText: crsIsGeographic(custom2CRS.text) ? "Lat, Long" : "X, Y"
    //visible: false
    text: ""

    onTextChanged: {
        if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return; }
        lastEditedBox = "custom2"; coordinatesDirty = true;
    }
}
//end of second custom box



 CrsPicker {
 id: custom2CRS
 Layout.fillWidth: true
 fieldFontSize: font_Size.text
 text: appSettings.crs2
 placeholderText: " EPSG"
 onTextChanged: {
     appSettings.crs2 = text
     var parts = wgs84Box.text.split(',').map(function(p) { return parseFloat(p.trim()) })
     if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1]))
         updateCoordinates(parts[1], parts[0], 4326, custom1CRS.text, custom2CRS.text)
 }
 }

 Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: custom2copy
    font.bold: true
    //visible: false
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(custom2BoxXY.text)
    }
 }
}


// wgs1984 
RowLayout{
 id: wgsdegreesrow
 visible: wgs84vis 
TextField {
 id: wgs84Box //5
  Layout.fillWidth: true
 font.bold: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.italic: true
 placeholderText: "Lat, Long "
 text: ""
 property bool isProgrammaticUpdate: false
 property bool hasError: false
 color: hasError ? "#cc0000" : palette.text

 onTextChanged: {

    if (isProgrammaticUpdate) {
 // Skip validation if the text is being updated programmatically
 isProgrammaticUpdate = false
 return
 }
    wgs84Box.placeholderText  = "Lat Long"
 var cursorPos = cursorPosition // Store cursor position
 var originalText = text

 // Clean input: allow digits, minus, dot, comma, and spaces
 var cleanedText = text.replace(/[^0-9-.,\s]/g, '')

 // Split by comma
 var parts = cleanedText.split(',')
 if (parts.length > 2) {
 cleanedText = parts[0] + ',' + parts[1]
 parts = cleanedText.split(',')
 }

 // Process each part
 for (var i = 0; i < parts.length; i++) {
 var num = parts[i].trim()

 // Allow partial input (e.g., "-", "45.", "45.1") during typing
 if (num === '' || num === '-' || num.match(/^-?\d*\.?\d*$/)) {
 // If it’s a valid partial number (including just a dot), keep it as-is
 parts[i] = num
 continue
 }

 // Remove extra dots (keep only the first one)
 var dots = (num.match(/\./g) || []).length
 if (dots > 1) {
 var firstDotIndex = num.indexOf('.')
 num = num.substring(0, firstDotIndex + 1) + num.substring(firstDotIndex + 1).replace(/\./g, '')
 }

 // Parse and clamp the value
 var value = parseFloat(num)
 if (isNaN(value)) {
 num = num.replace(/[^0-9-.]/g, '') // Remove invalid characters
 } else if (value < -90) {
 num = '-90'
 } else if (value > 90) {
 num = '90'
 } else {
 num = value.toString()
 }
 parts[i] = num
 }

 // Reconstruct the text
 cleanedText = parts[0] || ''
 if (parts.length > 1) {
 cleanedText += ', ' + (parts[1] || '')
 }

 // Update text only if it changed, and restore cursor
 if (text !== cleanedText) {
 text = cleanedText
 cursorPosition = cursorPos
 }
 lastEditedBox = "wgs84"; coordinatesDirty = true
 }
}
 Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: wgs84copy
    font.bold: true
    //visible: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(wgs84Box.text)
    }
}
}

// QR Code row — Show QR for current coords / Scan QR into plugin
RowLayout {
    Layout.fillWidth: true
    spacing: 6

    Button {
        text: qsTr("Show QR")
        font.pixelSize: 12
        font.bold: true
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        background: Rectangle { color: "#B3EBF2"; radius: 8 }
        contentItem: Text {
            text: parent.text; font: parent.font; color: "#333333"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
            ensureConverted()
            var coords = parseWgs84BoxCoords()
            if (!coords) { mainWindow.displayToast(qsTr("Convert coordinates first")); return }
            qrDialog.geoUri = "geo:" + coords.lat.toFixed(7) + "," + coords.lon.toFixed(7)
            qrDialog.open()
        }
    }

    Button {
        text: qsTr("Scan QR")
        font.pixelSize: 12
        font.bold: true
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        background: Rectangle { color: "#B3EBF2"; radius: 8 }
        contentItem: Text {
            text: parent.text; font: parent.font; color: "#333333"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
            if (!codeReader) { mainWindow.displayToast(qsTr("QR scanner not available")); return }
            _qrScanPending = true
            codeReader.open()
        }
    }
}

RowLayout{
    id: dmrow
    visible: dmvis
TextField {
 id: wgs84DMBox //6
  Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 font.bold: true
 placeholderText: "D M.mm  e.g. 51° 56.583' N,  9° 36.259' W"
 //visible: false
 text: ""

 property bool isProgrammaticUpdate: false
 property bool hasError: false
 color: hasError ? "#cc0000" : palette.text

 onTextChanged: {
    if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return; }
    hasError = false
    lastEditedBox = "ddm"; coordinatesDirty = true;
}}
 Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: wgsdm84copy
    font.bold: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(wgs84DMBox.text)
    }
}
 

}
RowLayout{
    id: dmsrow
    visible : dmsvis
TextField {
 id: wgs84DMSBox //6
  Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 font.bold: true
 placeholderText: "D M S.ss  e.g. 51° 56' 35.07\" N,  9° 36' 15.53\" W"
 text: ""

 property bool isProgrammaticUpdate: false
 property bool hasError: false
 color: hasError ? "#cc0000" : palette.text

 onTextChanged: {
    if (isProgrammaticUpdate) { isProgrammaticUpdate = false; return; }
    hasError = false
    lastEditedBox = "dms"; coordinatesDirty = true;
 }}
 Button {
    text: ""
    icon.source: "plugin_stuff/copy.svg"
    icon.width: 18
    icon.height: 18
    id: wgsdms84copy
    font.bold: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        ensureConverted(); copyToClipboard(wgs84DMSBox.text)
    }
}
 
}
// Seperate input boxes for lat Degrees, lon Minutes, lat Degrees and long minutes. 
// Entering decimals in the Degrees boxes will remove the minute boxes.
// update of the other coordinate boxes is achieved by button which enters the parsed 
// ddlat and ddlong from these boxes into the above wgs84Box.
 
RowLayout {
   
 id: latlongboxesDMS
 spacing: 5
 visible: dmsBoxesvis

 // Latitude Degrees
 TextField {
 id: latDegrees
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.bold: true
 font.family: "Arial"
 font.italic: true
 placeholderText: "D"
 leftPadding: 4
 rightPadding: 0
 validator: DoubleValidator {
 bottom: -90
 top: 90
 decimals: 5
 }
 Timer {
 id: latDegClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(latDegrees.text)
 if (!isNaN(value)) {
 value = Math.max(-90, Math.min(90, value))
 latDegrees.text = value // update to safe value (preserve decimals)
 }
 }
 }

 onTextChanged: {
     latDegClampTimer.restart(); lastEditedBox = "dms_boxes"; coordinatesDirty = true
     updateDMSBoxVisibility()
 }
 }

 // Latitude Minutes (decimal)
 TextField {
 id: latMinutes
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "M"
 validator: DoubleValidator {
 bottom: 0
 top: +60
 decimals: 4
 }
Timer {
 id: latMinClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(latMinutes.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(59.999, value))
 latMinutes.text = value
 }
 }
}
onTextChanged: {
 latMinClampTimer.restart(); lastEditedBox = "dms_boxes"; coordinatesDirty = true
var hideSecs = latMinutes.text.includes(".") || lonMinutes.text.includes(".")|| lonDegrees.text.includes(".")|| latDegrees.text.includes(".");
  lonSeconds.visible = !hideSecs;
  latSeconds.visible = !hideSecs;
  if (hideSecs== true) {lonSeconds.text = "" 
  latSeconds.text = ""}
}
 }

 // Latitude Seconds
 TextField {
 id: latSeconds
 visible: true
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "S"
 validator: DoubleValidator {
 bottom: 0
 top: 60
 decimals: 3
 }
 Timer {
 id: latSecClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(latSeconds.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(60, value))
 latSeconds.text = value
 }
 }
}
onTextChanged: { latSecClampTimer.restart(); lastEditedBox = "dms_boxes"; coordinatesDirty = true }

 }

 // Longitude Degrees
 TextField {
 id: lonDegrees
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
  font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
leftPadding: 4



 rightPadding: 0
 placeholderText: "D"
 validator: DoubleValidator {
 bottom: -180
 top: 180
 decimals: 5
 }
Timer {
 id: lonDegClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(lonDegrees.text)
 if (!isNaN(value)) {
 value = Math.max(-180, Math.min(180, value))
 lonDegrees.text = value
 }
 }
}
onTextChanged: {
     lonDegClampTimer.restart(); lastEditedBox = "dms_boxes"; coordinatesDirty = true
     updateDMSBoxVisibility()
 }
 }

 // Longitude Minutes (decimal)
 TextField {
 id: lonMinutes
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "M"
 validator: DoubleValidator {
 bottom: 0
 top: 60
 decimals: 4
 }
Timer {
 id: lonMinClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(lonMinutes.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(59.999, value))
 lonMinutes.text = value
 }
 }
}
onTextChanged: {
 lonMinClampTimer.restart(); lastEditedBox = "dms_boxes"; coordinatesDirty = true
 var hideSecs = latMinutes.text.includes(".") || lonMinutes.text.includes(".")|| lonDegrees.text.includes(".")|| latDegrees.text.includes(".");
  lonSeconds.visible = !hideSecs;
  latSeconds.visible = !hideSecs;
  if (hideSecs== true) {lonSeconds.text = "" 
  latSeconds.text = ""}

 }
 }

 // Longitude Seconds
 TextField {
 id: lonSeconds
 visible: true
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "S"
 validator: DoubleValidator {
 bottom: 0
 top: 60
 decimals: 3
 }
 Timer {
 id: lonSecClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(lonSeconds.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(60, value))
 lonSeconds.text = value
 }
 }
}
onTextChanged: { lonSecClampTimer.restart(); lastEditedBox = "dms_boxes"; coordinatesDirty = true }

 }


 }
 // Convert / Refresh Button
 Button {
    text: "Convert"
    font.bold: true
    font.pixelSize: 13
    Layout.fillWidth: true
    Layout.preferredHeight: 44
    background: Rectangle { color: "#80CC28"; radius: 8 }
    contentItem: Text {
        text: parent.text; font: parent.font; color: "white"
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    onClicked: { convertFromLastEdited() }
    onPressAndHold: {
        var latDeg = parseFloat(latDegrees.text) || 0
        var latMin = parseFloat(latMinutes.text) || 0
        var latSec = parseFloat(latSeconds.visible ? latSeconds.text : "0") || 0
        var lonDeg = parseFloat(lonDegrees.text) || 0
        var lonMin = parseFloat(lonMinutes.text) || 0
        var lonSec = parseFloat(lonSeconds.visible ? lonSeconds.text : "0") || 0
        var latD = (latDeg < 0) ? latDeg - latMin/60 - latSec/3600 : latDeg + latMin/60 + latSec/3600
        var lonD = (lonDeg < 0) ? lonDeg - lonMin/60 - lonSec/3600 : lonDeg + lonMin/60 + lonSec/3600
        wgs84Box.isProgrammaticUpdate = true
        wgs84Box.text = latD.toFixed(decimalsd.text) + ", " + lonD.toFixed(decimalsd.text)
        updateCoordinates(lonD, latD, 4326, custom1CRS.text, custom2CRS.text, 5)
        coordinatesDirty = false
        bigDialog2.open()
    }
 }
}

 
 
 
RowLayout{ 
 Label {
 id: label_2
 visible: true
 wrapMode: Text.Wrap
 font.bold: true
 text: qsTr("Do:")
 font.pixelSize: font_Size.text 
 font.family: "Arial" // Set font family
 font.italic: true // Make text italic
 } 
 
 Button {
 
 text: qsTr("Zoom/\nPan")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text  -3
 Layout.preferredHeight: 60 
onPressAndHold: { //pan to point
 var coords = parseWgs84BoxCoords()
 if (!coords) { mainWindow.displayToast(qsTr("Invalid coordinates")); return }
 var customcrsIN = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326");
 var customcrsOUT = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG);
 var transformedPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(coords.lon, coords.lat), customcrsIN, customcrsOUT);
 iface.mapCanvas().mapSettings.center.x = transformedPoint.x;
 iface.mapCanvas().mapSettings.center.y = transformedPoint.y;
 mainWindow.displayToast(transformedPoint.x + ", " + transformedPoint.y)
 mainDialog.close()
 }
  onClicked:{ // zoom to point
 var coords = parseWgs84BoxCoords()
 if (!coords) { mainWindow.displayToast(qsTr("Invalid coordinates")); return }
 zoomToPoint(coords.lon, coords.lat, 4326)
 mainDialog.close()
 }
 }
 
Button {
 text: qsTr("Add")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 Layout.preferredHeight: 60 

 onClicked: {
    var coords = parseWgs84BoxCoords()
    if (!coords) {
        mainWindow.displayToast(qsTr("Input some coordinates first!"))
        return
    }
    var pt = GeometryUtils.reprojectPoint(
        GeometryUtils.point(coords.lon, coords.lat),
        CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"),
        CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG))
    addPointToActiveLayer(
        GeometryUtils.createGeometryFromWkt(`POINT(${pt.x} ${pt.y})`),
        formOnAdd)
    doAfterAddAction(pt.x, pt.y, canvasEPSG)
    mainDialog.close();
 }
}


Button {
 visible: true
 text: "Navigate/\nWeb"
  Layout.fillWidth: true
 font.bold: true
 font.pixelSize: font_Size.text -3
 Layout.preferredHeight: 60 
 onClicked: {
 let navigation = iface.findItemByObjectName('navigation');
 var coords = parseWgs84BoxCoords()
 if (!coords) { mainWindow.displayToast(qsTr("Invalid coordinates")); return }
 var transformedPoint = GeometryUtils.reprojectPoint(
     GeometryUtils.point(coords.lon, coords.lat),
     CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"),
     CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG));
 iface.mapCanvas().mapSettings.center.x = transformedPoint.x;
 iface.mapCanvas().mapSettings.center.y = transformedPoint.y;
 mainWindow.displayToast("navigating to:" + transformedPoint.x + ", " + transformedPoint.y);
 navigation.destination = transformedPoint;
 mainDialog.close()
 }
  onPressAndHold: {
    var coords = parseWgs84BoxCoords()
    if (!coords) { mainWindow.displayToast(qsTr("Invalid coordinates")); return }
    Qt.openUrlExternally(buildMapsUrl(coords.lat, coords.lon));
    mainDialog.close()
}


}
Button {
 text: qsTr("BIG")
 
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 Layout.preferredHeight: 60 
 onClicked: { 
    ensureConverted(); bigDialog.open() 
    }

 onPressAndHold: {
     ensureConverted(); bigDialog2.open() 
     }
 }
 } 
 

 
} // end of big column

Dialog {
    id: settingsDialog
    parent: mainWindow.contentItem
    modal: true
    header: null
    width: Math.min(300, mainWindow.width - 16)
    height: Math.min(implicitHeight, mainWindow.height * 0.80)
    anchors.centerIn: parent
    onOpened: {
        populatePointLayerPicker()
        showFormOnAdd.checked = formOnAdd
    }

ScrollView {
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

Column {
    width: parent.width
    spacing: 2
    topPadding: 6; bottomPadding: 6

    // shared header style: bold, 10px, small gap beneath
    Label { text: qsTr("Add new points to:"); font.pixelSize: 10; font.bold: true }
    Item  { width: 1; height: 2 }
    ComboBox {
        id: pointLayerCombo
        width: parent.width
        implicitHeight: 32
        font.pixelSize: 10
        model: pointLayerPickerModel
        textRole: "name"
        onActivated: {
            var item = pointLayerPickerModel.get(currentIndex)
            if (item.isHeader) { currentIndex = currentIndex > 0 ? currentIndex - 1 : 0; return }
            appSettings.pointLayerName = (currentIndex === 0) ? "" : item.name
        }
        delegate: ItemDelegate {
            width: pointLayerCombo.width
            enabled: !model.isHeader
            contentItem: Text {
                text: model.name
                font.pixelSize: 10
                font.italic: model.isHeader
                color: model.isHeader ? "#888888" : (highlighted ? "#ffffff" : "#000000")
                verticalAlignment: Text.AlignVCenter
                leftPadding: model.isHeader ? 4 : 8
            }
            highlighted: pointLayerCombo.highlightedIndex === index
        }
    }

    Rectangle { width: parent.width; height: 1; color: "#cccccc" }
    Item { width: 1; height: 3 }
    ButtonGroup { id: afterAddGroup }
    Label { text: qsTr("After adding point"); font.pixelSize: 10; font.bold: true }
    Item  { width: 1; height: 2 }
    RowLayout {
        width: parent.width
        RadioButton { id: afterAddNothing; text: qsTr("No Zoom/Pan"); font.pixelSize: 9; implicitHeight: 28; ButtonGroup.group: afterAddGroup; checked: appSettings.afterAddAction === 0; onCheckedChanged: if (checked) appSettings.afterAddAction = 0 }
        RadioButton { id: afterAddPan;     text: qsTr("Pan to");  font.pixelSize: 9; implicitHeight: 28; ButtonGroup.group: afterAddGroup; checked: appSettings.afterAddAction === 1; onCheckedChanged: if (checked) appSettings.afterAddAction = 1 }
        RadioButton { id: afterAddZoom;    text: qsTr("Zoom to:"); font.pixelSize: 9; implicitHeight: 28; ButtonGroup.group: afterAddGroup; checked: appSettings.afterAddAction === 2; onCheckedChanged: if (checked) appSettings.afterAddAction = 2 }
    }
    ComboBox {
        id: zoomPresetCombo
        width: parent.width; implicitHeight: 26
        font.pixelSize: 9
        model: ["Detail (~25 m)", "Building (~50 m)", "Street (~500 m)", "Town (~2 km)", "Region (~20 km)", "Country (~200 km)"]
        currentIndex: appSettings.zoomPreset
        onCurrentIndexChanged: appSettings.zoomPreset = currentIndex
    }
    CheckBox { id: showFormOnAdd; text: qsTr("Show form (NB hiding may override hard restraints)"); font.pixelSize: 9; implicitHeight: 26; onCheckedChanged: { formOnAdd = checked; appSettings.showFeatureForm = checked } }

    Rectangle { width: parent.width; height: 1; color: "#cccccc" }
    Item { width: 1; height: 3 }
    Label { text: qsTr("Display"); font.pixelSize: 10; font.bold: true }
    Item  { width: 1; height: 2 }
    GridLayout {
        width: parent.width
        columns: 3; columnSpacing: 0; rowSpacing: 0
        CheckBox { id: showIG;        text: "Irish Grid"; font.pixelSize: 9; implicitHeight: 26; checked: true;  onCheckedChanged: { igridrow.visible = checked;        appSettings.showIG = checked } }
        CheckBox { id: showDegrees;   text: "Degrees";    font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { wgsdegreesrow.visible = checked;   appSettings.showDegrees = checked } }
        CheckBox { id: showDMS;       text: "D M S.ss";   font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { dmsrow.visible = checked;          appSettings.showDMS = checked } }
        CheckBox { id: showUK;        text: "UK Grid";    font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { ukgridrow.visible = checked;       appSettings.showUK = checked } }
        CheckBox { id: showDM;        text: "D M.mm";     font.pixelSize: 9; implicitHeight: 26; checked: true;  onCheckedChanged: { dmrow.visible = checked;           appSettings.showDM = checked } }
        CheckBox { id: showCustom1;   text: "Custom 1";   font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { custom1row.visible = checked;      appSettings.showCustom1 = checked } }
        CheckBox { id: showCustom2;   text: "Custom 2";   font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { custom2row.visible = checked;      appSettings.showCustom2 = checked } }
        CheckBox { id: showMGRS;      text: "MGRS";       font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { mgrsrow.visible = checked;         appSettings.showMGRS = checked } }
        CheckBox { id: showPlusCode;  text: "Plus Code";  font.pixelSize: 9; implicitHeight: 26; checked: false; onCheckedChanged: { pluscoderow.visible = checked;     appSettings.showPlusCode = checked } }
        CheckBox { id: showDMSboxes;  text: "DMS Boxes";  font.pixelSize: 9; implicitHeight: 26; checked: true;  onCheckedChanged: { latlongboxesDMS.visible = checked; appSettings.showDMSboxes = checked } }
    }
      GridLayout {
        width: parent.width
        columns: 2; columnSpacing: 0; rowSpacing: 0
    CheckBox { id: showCrosshair; text: "Crosshair";  font.pixelSize: 9; implicitHeight: 26; checked: true;  onCheckedChanged: { crosshair.visible = checked;       appSettings.showCrosshair = checked } }
    CheckBox { id: useNSEWCheck; text: "N/S/E/W labels (vs +/-)"; font.pixelSize: 9; implicitHeight: 26; checked: appSettings.useNSEW; onCheckedChanged: { appSettings.useNSEW = checked; if (_lastX !== 0 || _lastY !== 0) updateCoordinates(_lastX, _lastY, _lastEPSG, custom1CRS.text, custom2CRS.text) } }
      }
    Rectangle { width: parent.width; height: 1; color: "#cccccc" }
    Item { width: 1; height: 3 }
    ButtonGroup { id: mapsUrlGroup }
    Label { text: qsTr("External map"); font.pixelSize: 10; font.bold: true }
    Item  { width: 1; height: 2 }
    GridLayout {
        width: parent.width
        columns: 2; columnSpacing: 0; rowSpacing: 0
        RadioButton { text: "GMaps pin";  font.pixelSize: 9; implicitHeight: 26; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 1; onCheckedChanged: if (checked) { mapsUrlOption = 1; appSettings.mapsUrlOption = 1 } }
        RadioButton { text: "GMaps nav";  font.pixelSize: 9; implicitHeight: 26; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 2; onCheckedChanged: if (checked) { mapsUrlOption = 2; appSettings.mapsUrlOption = 2 } }
        RadioButton { text: "OSM";        font.pixelSize: 9; implicitHeight: 26; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 3; onCheckedChanged: if (checked) { mapsUrlOption = 3; appSettings.mapsUrlOption = 3 } }
        RadioButton { text: "OSRM route"; font.pixelSize: 9; implicitHeight: 26; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 4; onCheckedChanged: if (checked) { mapsUrlOption = 4; appSettings.mapsUrlOption = 4 } }
    }

    Rectangle { width: parent.width; height: 1; color: "#cccccc" }
    Item { width: 1; height: 3 }
    Label { text: qsTr("Format"); font.pixelSize: 10; font.bold: true }
    Item  { width: 1; height: 2 }
    GridLayout {
        width: parent.width
        columns: 2; columnSpacing: 0; rowSpacing: 0
        Label { font.pixelSize: 9; text: "Font Size:" }
        TextField {
            id: font_Size; font.pixelSize: 9; text: fsize
            Layout.preferredWidth: 36; Layout.preferredHeight: 22
            validator: IntValidator { bottom: 5; top: 25 }
            onTextChanged: appSettings.fontSize = text
        }
        Label { font.pixelSize: 9; text: "Decimals (m):" }
        TextField {
            id: decimalsm; font.pixelSize: 9; text: decm
            Layout.preferredWidth: 36; Layout.preferredHeight: 22
            validator: IntValidator { bottom: 0; top: 10 }
            onTextChanged: appSettings.decimalsM = text
        }
        Label { font.pixelSize: 9; text: "Decimals (deg):" }
        TextField {
            id: decimalsd; font.pixelSize: 9; text: decd
            Layout.preferredWidth: 36; Layout.preferredHeight: 22
            validator: IntValidator { bottom: 0; top: 10 }
            onTextChanged: appSettings.decimalsD = text
        }
    }

    Button {
        text: qsTr("Reset")
        width: parent.width
        font.pixelSize: 10
        implicitHeight: 32
        onClicked: {
            custom1CRS.text = canvasEPSG;   custom2CRS.text = "4326"
            appSettings.crs1 = String(canvasEPSG); appSettings.crs2 = "4326"
            font_Size.text  = fsize;        appSettings.fontSize  = fsize
            decimalsm.text  = decm;         appSettings.decimalsM = decm
            decimalsd.text  = decd;         appSettings.decimalsD = decd
            zoomPresetCombo.currentIndex = zoomPresetDefault; appSettings.zoomPreset = zoomPresetDefault
            showIG.checked      = igvis;    showUK.checked        = ukgvis
            showCustom1.checked = custom1vis; showCustom2.checked = custom2vis
            showDegrees.checked = wgs84vis
            showDM.checked      = dmvis;    showDMS.checked       = dmsvis
            showDMSboxes.checked = dmsBoxesvis; showCrosshair.checked = crosshairvis
            showMGRS.checked = mgrsvis; showPlusCode.checked = pluscodevis
            formOnAdd = showFeatureFormDefault; showFormOnAdd.checked = showFeatureFormDefault; appSettings.showFeatureForm = showFeatureFormDefault
            appSettings.afterAddAction = afterAddDefault; afterAddGroup.checkedButton = [afterAddNothing, afterAddPan, afterAddZoom][afterAddDefault]
            mapsUrlOption = 3;              appSettings.mapsUrlOption = 3
            appSettings.pointLayerName = ""; pointLayerCombo.currentIndex = 0
            appSettings.useNSEW = false; useNSEWCheck.checked = false
        }
    }

    Label {
        text: filetimedate
        width: parent.width
        font.pixelSize: 9; font.italic: true
        horizontalAlignment: Text.AlignRight
    }
} // end of column
} // end of ScrollView
} // end of settingsDialog
Dialog {
    id: bigDialog
    font.pixelSize: 35
    width: 350
    height: 400
    modal: true
    anchors.centerIn: parent

    Column {
        spacing: 20
        width: parent.width
        anchors.centerIn: parent

        // GPS Box
        Rectangle {
            id: gpsBox
            width: parent.width
            implicitHeight: childrenRect.height + 20
            color: "#D9CCE7"
            radius: 10
            border.color: "black"
            border.width: 0.5
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                id: childrenRect
                width: parent.width
                spacing: 10
                anchors.margins: 10
                anchors.centerIn: parent

                Label {
                    text: "GPS"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // IG (GPS)
                MouseArea {
                    width: parent.width
                    height: gpsIG.implicitHeight
                    onClicked: {
                        copyToClipboard(gpsIG.text)
                    }

                    Label {
                        id: gpsIG
                        text: (positionSource.active && positionSource.positionInformation.latitudeValid && positionSource.positionInformation.longitudeValid)
                            ? bestGridRef(positionSource.projectedPosition, canvasEPSG)
                            : "No GPS"
                        font.pixelSize: gpsIG.text.indexOf("°") >= 0 ? 24 : 35
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // LL (GPS)
                MouseArea {
                    width: parent.width
                    height: gpsLL.implicitHeight
                    onClicked: {
                        copyToClipboard(gpsLL.text)
                    }

                    Label {
                        id: gpsLL
                        text: (positionSource.active && positionSource.positionInformation.latitudeValid && positionSource.positionInformation.longitudeValid)
                            ? justLL(positionSource.projectedPosition, canvasEPSG)
                            : ""
                        font.pixelSize: 30
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // Screen Center Box
        Rectangle {
            id: screenBox
            width: parent.width
            implicitHeight: childrenRect2.height + 20
            color: "#f0f0f0"
            radius: 10
            border.color: "black"
            border.width: 0.5
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                id: childrenRect2
                width: parent.width
                spacing: 10
                anchors.margins: 10
                anchors.centerIn: parent

                Label {
                    text: "Screen Center"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // IG (Screen Center)
                MouseArea {
                    width: parent.width
                    height: screenIG.implicitHeight
                    onClicked: {
                        copyToClipboard(screenIG.text)
                    }

                    Label {
                        id: screenIG
                        text: bestGridRef(canvas.center, canvasEPSG)
                        font.pixelSize: screenIG.text.indexOf("°") >= 0 ? 24 : 35
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // LL (Screen Center)
                MouseArea {
                    width: parent.width
                    height: screenLL.implicitHeight
                    onClicked: {
                        copyToClipboard(screenLL.text)
                    }

                    Label {
                        id: screenLL
                        text: justLL(canvas.center, canvasEPSG)
                        font.pixelSize: 30
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}

Dialog {
    id: bigDialog2
    font.pixelSize: 35
    width: 400
    height: 350
    modal: true
    anchors.centerIn: parent

    // Third Box: Box contents
    Rectangle {
        id: boxBox
        width: parent.width
        implicitHeight: childrenRect3.height + 20
        color: "#f0fef0"
        radius: 10
        border.color: "black"
        border.width: 0.5
        anchors.horizontalCenter: parent.horizontalCenter

        Column {
            id: childrenRect3
            width: parent.width
            spacing: 10
            anchors.margins: 10
            anchors.centerIn: parent

            Label {
                text: "Text box contents"
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // igInputBox text
            MouseArea {
                width: parent.width
                height: igCopy.implicitHeight
                onClicked: {
                    copyToClipboard(igCopy.text)
                }

                Label {
                    id: igCopy
                    text: igInputBox.text
                    font.pixelSize: 35
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // wgs84Box text
            MouseArea {
                width: parent.width
                height: wgs84Copy.implicitHeight
                onClicked: {
                    copyToClipboard(wgs84Copy.text)
                }

                Label {
                    id: wgs84Copy
                    text: wgs84Box.text
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // wgs84DMBox text
            MouseArea {
                width: parent.width
                height: wgs84DMCopy.implicitHeight
                onClicked: {
                    copyToClipboard(wgs84DMCopy.text)
                }

                Label {
                    id: wgs84DMCopy
                    text: wgs84DMBox.text
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // wgs84DMSBox text
            MouseArea {
                width: parent.width
                height: wgs84DMSCopy.implicitHeight
                onClicked: {
                    copyToClipboard(wgs84DMSCopy.text)
                }

                Label {
                    id: wgs84DMSCopy
                    text: wgs84DMSBox.text
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}

}
 




 // Lookup table for the IG letter matrix (for EPSG:29903 /29902)
 property var igletterMatrix: {
 'V': { first: 0, second: 0 },
 'W': { first: 1, second: 0 },
 'X': { first: 2, second: 0 },
 'Y': { first: 3, second: 0 },
 'Z': { first: 4, second: 0 },
 'Q': { first: 0, second: 1 },
 'R': { first: 1, second: 1 },
 'S': { first: 2, second: 1 },
 'T': { first: 3, second: 1 },
 'L': { first: 0, second: 2 },
 'M': { first: 1, second: 2 },
 'N': { first: 2, second: 2 },
 'O': { first: 3, second: 2 },
 'P': { first: 4, second: 2 },
 'F': { first: 0, second: 3 },
 'G': { first: 1, second: 3 },
 'H': { first: 2, second: 3 },
 'J': { first: 3, second: 3 },
 'K': { first: 4, second: 3 },
 'A': { first: 0, second: 4 },
 'B': { first: 1, second: 4 },
 'C': { first: 2, second: 4 },
 'D': { first: 3, second: 4 },
 'E': { first: 4, second: 4 }
 }
// Lookup table for the UK letter matrix (for EPSG:27700)
property var ukletterMatrix: {
 'SV': { first: 0, second: 0 },
 'SW': { first: 1, second: 0 },
 'SX': { first: 2, second: 0 },
 'SY': { first: 3, second: 0 },
 'SZ': { first: 4, second: 0 },
 'TV': { first: 5, second: 0 },
 'SR': { first: 1, second: 1 },
 'SS': { first: 2, second: 1 },
 'ST': { first: 3, second: 1 },
 'SU': { first: 4, second: 1 },
 'TQ': { first: 5, second: 1 },
 'TR': { first: 6, second: 1 },
 'SM': { first: 1, second: 2 },
 'SN': { first: 2, second: 2 },
 'SO': { first: 3, second: 2 },
 'SP': { first: 4, second: 2 },
 'TL': { first: 5, second: 2 },
 'TM': { first: 6, second: 2 },
 'SH': { first: 2, second: 3 },
 'SJ': { first: 3, second: 3 },
 'SK': { first: 4, second: 3 },
 'TF': { first: 5, second: 3 },
 'TG': { first: 6, second: 3 },
 'SC': { first: 2, second: 4 },
 'SD': { first: 3, second: 4 },
 'SE': { first: 4, second: 4 },
 'TA': { first: 5, second: 4 },
 'NW': { first: 1, second: 5 },
 'NX': { first: 2, second: 5 },
 'NY': { first: 3, second: 5 },
 'NZ': { first: 4, second: 5 },
 'OV': { first: 5, second: 5 },
 'NR': { first: 1, second: 6 },
 'NS': { first: 2, second: 6 },
 'NT': { first: 3, second: 6 },
 'NU': { first: 4, second: 6 },
 'NL': { first: 0, second: 7 },
 'NM': { first: 1, second: 7 },
 'NN': { first: 2, second: 7 },
 'NO': { first: 3, second: 7 },
 'HW': { first: 1, second: 10 },
 'HX': { first: 2, second: 10 },
 'HY': { first: 3, second: 10 },
 'HZ': { first: 4, second: 10 },
 'NF': { first: 0, second: 8 },
 'NG': { first: 1, second: 8 },
 'NH': { first: 2, second: 8 },
 'NJ': { first: 3, second: 8 },
 'NK': { first: 4, second: 8 },
 'NA': { first: 0, second: 9 },
 'NB': { first: 1, second: 9 },
 'NC': { first: 2, second: 9 },
 'ND': { first: 3, second: 9 },
 'HT': { first: 3, second: 11 },
 'HU': { first: 4, second: 11 },
 'HP': { first: 4, second: 12 }}

function validateInput(textBox) {
    // Your validation logic here
    console.log("Validating input for:", textBox.objectName);

    // Example validation logic
    var inputText = textBox.text;
    var cleanedText = inputText.replace(/[^0-9-.,\s]/g, '');
    var parts = cleanedText.split(',');

    if (parts.length > 2) {
        cleanedText = parts[0] + ',' + parts[1];
        parts = cleanedText.split(',');
    }

    // Process each part
    for (var i = 0; i < parts.length; i++) {
        var num = parts[i].trim();

        if (num === '' || num === '-' || num.match(/^-?\d*\.?\d*$/)) {
            parts[i] = num;
            continue;
        }

        var dots = (num.match(/\./g) || []).length;
        if (dots > 1) {
            var firstDotIndex = num.indexOf('.');
            num = num.substring(0, firstDotIndex + 1) + num.substring(firstDotIndex + 1).replace(/\./g, '');
        }

        var value = parseFloat(num);
        if (isNaN(value)) {
            num = num.replace(/[^0-9-.]/g, '');
        } else if (value < -1000000) {
            num = '';
        } else if (value > 1000000) {
            num = '';
        } else {
            num = value.toString();
        }
        parts[i] = num;
    }

    // Reconstruct the text
    cleanedText = parts[0] || '';
    if (parts.length > 1) {
        cleanedText += ', ' + (parts[1] || '');
    }

    // Update the text box if the text has changed
    if (textBox.text !== cleanedText) {
        textBox.isProgrammaticUpdate = true;
        textBox.text = cleanedText;
    }
}

// Converts a projected (x, y) coordinate to a national grid reference string
// (e.g. "H 54321 89797" for Irish Grid, "NS 45140 72887" for UK Grid).
// Works for both grids — pass the appropriate maxCoord and letterMatrix:
//   Irish Grid:  maxCoord = 1 000 000,  letterMatrix = igletterMatrix
//   UK Grid:     maxCoord = 10 000 000, letterMatrix = ukletterMatrix
// The algorithm divides x/y into 100 km tiles, looks up the tile letter(s),
// then takes the remainder within the tile as a zero-padded 5-digit number.
function getGridRefFromXY(x, y, maxCoord, letterMatrix) {
    if (x < 0 || y < 0 || x >= maxCoord || y >= maxCoord) return ""
    var firstIndex  = Math.floor(x / 100000)
    var secondIndex = Math.floor(y / 100000)
    var letters = Object.keys(letterMatrix).find(function(key) {
        return letterMatrix[key].first === firstIndex && letterMatrix[key].second === secondIndex
    })
    if (!letters) return ""
    return letters + ' ' + String(Math.round(x % 100000)).padStart(5, '0') + ' ' + String(Math.round(y % 100000)).padStart(5, '0')
}

function getIGFromXY(x, y) { return getGridRefFromXY(x, y, 1000000,  igletterMatrix) }
function getUKFromXY(x, y) { return getGridRefFromXY(x, y, 10000000, ukletterMatrix) }

function decimalToDDM(decimal, isLat) {
 if (typeof decimal !== 'number' || isNaN(decimal)) return ''
 var absDecimal = Math.abs(decimal)
 var degrees = Math.floor(absDecimal)
 var minutes = (absDecimal - degrees) * 60
 if (appSettings.useNSEW && isLat !== undefined) {
     var dir = isLat ? (decimal >= 0 ? "N" : "S") : (decimal >= 0 ? "E" : "W")
     return degrees + "° " + minutes.toFixed(3) + "' " + dir
 }
 var sign = decimal < 0 ? "-" : ""
 return sign + degrees + "° " + minutes.toFixed(3) + "'"
}
 


function decTODeg(decimal) {
if (typeof decimal !== 'number' || isNaN(decimal)) {
 return ''
 }
 
 const sign = decimal < 0 ? -1 : 1
 const absDecimal = Math.abs(decimal)
 return Math.floor(absDecimal) * sign
}



function degtoSeconds(decimal) {
 if (typeof decimal !== 'number' || isNaN(decimal)) {
 return ''
 }
 
 const absDecimal = Math.abs(decimal)
 const degrees = Math.floor(absDecimal)
 const minutes = (absDecimal - degrees) * 60
 return ((minutes - Math.floor(minutes)) * 60).toFixed(2)
}

// Reprojects (x, y) from sourceEPSG and updates every coordinate display box
// EXCEPT the one that triggered the call (to avoid infinite update loops).
// inputDialog values:
//   1 = Irish Grid input      (igInputBox)
//   2 = UK Grid input         (ukInputBox)
//   3 = Custom 1 input        (custom1BoxXY)
//   4 = Custom 2 input        (custom2BoxXY)
//   5 = WGS84 decimal input   (wgs84Box)
//   6 = WGS84 DDM/DMS input   (wgs84DMBox / DMS boxes)
//   undefined = external call — update everything
// isProgrammaticUpdate is set before each text assignment to suppress the
// box's own onTextChanged handler from firing a second updateCoordinates call.
 function updateCoordinates(x, y, sourceEPSG, targetEPSG1, targetEPSG2, inputDialog) {
 _clearErrors()
 _lastX = x; _lastY = y; _lastEPSG = sourceEPSG
 coordinatesDirty = false
 var sourceCrs = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(sourceEPSG))
 var targetCrs1 = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(targetEPSG1))
 var targetCrs2 = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(targetEPSG2))
 var wgs84Crs = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326")
 // Reproject to WGS84 once — reused by WGS84 box, DDM, MGRS, and Plus Code blocks
 var wgs84Point = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, wgs84Crs)

 if (inputDialog !== 1) { // Update IG
 var igPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, CoordinateReferenceSystemUtils.fromDescription("EPSG:29903"))
 var igRef = getIGFromXY(igPoint.x, igPoint.y)
 igInputBox.isProgrammaticUpdate = true
 igInputBox.text = igRef
 // Hide the row when the point is outside Irish Grid coverage (result is "")
 igridrow.visible = showIG.checked && igRef !== ""
 }

 if (inputDialog !== 2) { // Update UK
 var ukPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, CoordinateReferenceSystemUtils.fromDescription("EPSG:27700"))
 var ukRef = getUKFromXY(ukPoint.x, ukPoint.y)
 ukInputBox.isProgrammaticUpdate = true
 ukInputBox.text = ukRef
 // Hide the row when the point is outside UK Grid coverage (result is "")
 ukgridrow.visible = showUK.checked && ukRef !== ""
 }

 if (inputDialog !== 3) { // Update Custom1
 var custom1Point = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, targetCrs1)
 custom1BoxXY.isProgrammaticUpdate = true
 custom1BoxXY.text = formatPoint(custom1Point, targetCrs1)
 }

 if (inputDialog !== 4) { // Update Custom2
 var custom2Point = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, targetCrs2)
 custom2BoxXY.isProgrammaticUpdate = true
 custom2BoxXY.text = formatPoint(custom2Point, targetCrs2)
 }

 if (inputDialog !== 5) { // Update WGS84
 wgs84Box.isProgrammaticUpdate = true
 if (appSettings.useNSEW) {
     var latVal = wgs84Point.y; var lonVal = wgs84Point.x
     var latStr = Math.abs(latVal).toFixed(decimalsd.text) + (latVal >= 0 ? " N" : " S")
     var lonStr = Math.abs(lonVal).toFixed(decimalsd.text) + (lonVal >= 0 ? " E" : " W")
     wgs84Box.text = latStr + ",  " + lonStr
 } else {
     wgs84Box.text = parseFloat(wgs84Point.y.toFixed(decimalsd.text)) + ", " + parseFloat(wgs84Point.x.toFixed(decimalsd.text))
 }
 }

 if (inputDialog !== 6) { // Update WGS84 DDM
 wgs84DMBox.isProgrammaticUpdate = true
 wgs84DMBox.text = decimalToDDM(wgs84Point.y, true) + ",  " + decimalToDDM(wgs84Point.x, false)

 wgs84DMSBox.text = decimalToDMss(wgs84Point.y, true) + ",  " + decimalToDMss(wgs84Point.x, false)

 // Update d m s boxes
 latDegrees.text = decTODeg(wgs84Point.y)
 latMinutes.text = decimalToMinutes(wgs84Point.y)
 latSeconds.text = degtoSeconds(wgs84Point.y)
 lonDegrees.text = decTODeg(wgs84Point.x)
 lonMinutes.text = decimalToMinutes(wgs84Point.x)
 lonSeconds.text = degtoSeconds(wgs84Point.x)

 }

 if (inputDialog !== 7) { // Update MGRS
     var mgrsStr = latLonToMgrs(wgs84Point.y, wgs84Point.x, 5)
     mgrsBox.isProgrammaticUpdate = true
     mgrsBox.text = mgrsStr
     mgrsrow.visible = showMGRS.checked && mgrsStr !== ""
 }

 if (inputDialog !== 8) { // Update Plus Code
     var olcStr = OLC.encode(wgs84Point.y, wgs84Point.x, 11)
     pluscodeBox.isProgrammaticUpdate = true
     pluscodeBox.text = olcStr
 }

 // Helmert accuracy warning — shown once per unique EPSG combination
 var _helmertWarnings = {
     "27700": "BNG (27700): ~3-5m accuracy — OSTN15 grid not loaded",
     "29903": "Irish Grid (29903): ~1-3m accuracy — OSTNI15 grid not loaded",
     "29902": "Irish Grid (29902): ~1-3m accuracy — OSTNI15 grid not loaded",
     "29900": "Irish Grid (29900): ~1-3m accuracy — OSTNI15 grid not loaded"
 }
 var _epsgKey = String(sourceEPSG) + "|" + String(parseInt(targetEPSG1)) + "|" + String(parseInt(targetEPSG2))
 if (_epsgKey !== _lastWarnedEPSGs) {
     var _epsgList = [String(sourceEPSG), String(parseInt(targetEPSG1)), String(parseInt(targetEPSG2))]
     for (var _i = 0; _i < _epsgList.length; _i++) {
         if (_helmertWarnings[_epsgList[_i]]) {
             mainWindow.displayToast(qsTr("⚠ " + _helmertWarnings[_epsgList[_i]]))
             _lastWarnedEPSGs = _epsgKey
             break
         }
     }
     if (!_helmertWarnings[_epsgList[0]] && !_helmertWarnings[_epsgList[1]] && !_helmertWarnings[_epsgList[2]])
         _lastWarnedEPSGs = _epsgKey  // no warning needed — still update so we don't recheck
 }
 }

// Auto-converts from last edited box if coordinates are dirty
function convertFromLastEdited() {
        if (lastEditedBox === "dms_boxes") {
            var latDeg = parseFloat(latDegrees.text) || 0
            var latMin = parseFloat(latMinutes.text) || 0
            var latSec = parseFloat(latSeconds.text) || 0
            var lonDeg = parseFloat(lonDegrees.text) || 0
            var lonMin = parseFloat(lonMinutes.text) || 0
            var lonSec = parseFloat(lonSeconds.text) || 0
            var lat = (latDeg < 0) ? latDeg - latMin/60 - latSec/3600 : latDeg + latMin/60 + latSec/3600
            var lon = (lonDeg < 0) ? lonDeg - lonMin/60 - lonSec/3600 : lonDeg + lonMin/60 + lonSec/3600
            if (Math.abs(lat) > 90)       { mainWindow.displayToast(qsTr("Latitude must be between -90 and 90")); return }
            if (Math.abs(lon) > 180)      { mainWindow.displayToast(qsTr("Longitude must be between -180 and 180")); return }
            wgs84Box.isProgrammaticUpdate = true
            wgs84Box.text = lat.toFixed(decimalsd.text) + ", " + lon.toFixed(decimalsd.text)
            updateCoordinates(lon, lat, 4326, custom1CRS.text, custom2CRS.text, 5)
        } else if (lastEditedBox === "wgs84") {
            var parts = wgs84Box.text.split(",")
            if (parts.length === 2) {
                var lat = parseCoordPart(parts[0].trim()); var lon = parseCoordPart(parts[1].trim())
                if (lat !== null && lon !== null) {
                    if (Math.abs(lat) > 90)        _setError(wgs84Box, "Latitude must be between -90 and 90")
                    else if (Math.abs(lon) > 180)  _setError(wgs84Box, "Longitude must be between -180 and 180")
                    else                           updateCoordinates(lon, lat, 4326, custom1CRS.text, custom2CRS.text, 5)
                } else _setError(wgs84Box, "Invalid WGS84 decimal input")
            }
        } else if (lastEditedBox === "ddm") {
            var p = parseDegreeCoordPair(wgs84DMBox.text)
            if (p !== null) {
                if      (Math.abs(p.lat) > 90)  _setError(wgs84DMBox, "Latitude must be between -90 and 90")
                else if (Math.abs(p.lon) > 180) _setError(wgs84DMBox, "Longitude must be between -180 and 180")
                else                            updateCoordinates(p.lon, p.lat, 4326, custom1CRS.text, custom2CRS.text, 6)
            } else _setError(wgs84DMBox, "Cannot parse DDM input")
        } else if (lastEditedBox === "dms") {
            var p = parseDegreeCoordPair(wgs84DMSBox.text)
            if (p !== null) {
                if      (Math.abs(p.lat) > 90)  _setError(wgs84DMSBox, "Latitude must be between -90 and 90")
                else if (Math.abs(p.lon) > 180) _setError(wgs84DMSBox, "Longitude must be between -180 and 180")
                else                            updateCoordinates(p.lon, p.lat, 4326, custom1CRS.text, custom2CRS.text, 6)
            } else _setError(wgs84DMSBox, "Cannot parse DMS input")
        } else if (lastEditedBox === "ig") {
            var igm = igInputBox.text.match(/^([A-Za-z])\s(\d{1,5})\s(\d{1,5})$/)
            if (igm && igm[2].length === igm[3].length && igletterMatrix[igm[1].toUpperCase()]) {
                var letter = igm[1].toUpperCase()
                var X5 = parseInt(igm[2].padEnd(5, '0'), 10)
                var Y5 = parseInt(igm[3].padEnd(5, '0'), 10)
                var me = igletterMatrix[letter]
                updateCoordinates(X5 + me.first*100000, Y5 + me.second*100000, 29903, custom1CRS.text, custom2CRS.text, 1)
            } else _setError(igInputBox, "Incomplete Irish Grid reference")
        } else if (lastEditedBox === "uk") {
            var ukm = ukInputBox.text.match(/^([A-Za-z]{2})\s(\d{1,5})\s(\d{1,5})$/)
            if (ukm && ukm[2].length === ukm[3].length && ukletterMatrix[ukm[1].toUpperCase()]) {
                var letter = ukm[1].toUpperCase()
                var X5 = parseInt(ukm[2].padEnd(5, '0'), 10)
                var Y5 = parseInt(ukm[3].padEnd(5, '0'), 10)
                var me = ukletterMatrix[letter]
                updateCoordinates(X5 + me.first*100000, Y5 + me.second*100000, 27700, custom1CRS.text, custom2CRS.text, 2)
            } else _setError(ukInputBox, "Incomplete UK Grid reference")
        } else if (lastEditedBox === "custom1") {
            var parts = custom1BoxXY.text.split(",").map(function(p){ return parseFloat(p.trim()) })
            if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                var c1geo = crsIsGeographic(custom1CRS.text)
                if (c1geo && Math.abs(parts[0]) > 90)  { _setError(custom1BoxXY, "Latitude must be between -90 and 90"); }
                else if (c1geo && Math.abs(parts[1]) > 180) { _setError(custom1BoxXY, "Longitude must be between -180 and 180"); }
                else { updateCoordinates(c1geo ? parts[1] : parts[0], c1geo ? parts[0] : parts[1], custom1CRS.text, custom1CRS.text, custom2CRS.text, 3) }
            } else _setError(custom1BoxXY, "Invalid Custom 1 input")
        } else if (lastEditedBox === "custom2") {
            var parts = custom2BoxXY.text.split(",").map(function(p){ return parseFloat(p.trim()) })
            if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                var c2geo = crsIsGeographic(custom2CRS.text)
                if (c2geo && Math.abs(parts[0]) > 90)  { _setError(custom2BoxXY, "Latitude must be between -90 and 90"); }
                else if (c2geo && Math.abs(parts[1]) > 180) { _setError(custom2BoxXY, "Longitude must be between -180 and 180"); }
                else { updateCoordinates(c2geo ? parts[1] : parts[0], c2geo ? parts[0] : parts[1], custom2CRS.text, custom1CRS.text, custom2CRS.text, 4) }
            } else _setError(custom2BoxXY, "Invalid Custom 2 input")
        } else if (lastEditedBox === "mgrs") {
            var ll = mgrsToLatLon(mgrsBox.text)
            if (ll !== null) updateCoordinates(ll.lon, ll.lat, 4326, custom1CRS.text, custom2CRS.text, 7)
            else _setError(mgrsBox, "Cannot parse MGRS reference")
        } else if (lastEditedBox === "pluscode") {
            var decoded = OLC.decode(pluscodeBox.text.trim().toUpperCase())
            if (decoded !== null) updateCoordinates(decoded.longitudeCenter, decoded.latitudeCenter, 4326, custom1CRS.text, custom2CRS.text, 8)
            else _setError(pluscodeBox, "Cannot parse Plus Code")
        }
    }
function ensureConverted() { if (coordinatesDirty) convertFromLastEdited() }

// Parses a single lat or lon value from any of: decimal, DDM, DMS, with optional N/S/E/W.
// Call after normalising °'" to spaces. Returns decimal degrees, or null if unparseable.
function parseCoordPart(s) {
    s = s.trim();
    var hemi = '';
    var hLead = s.match(/^([NSEWnsew])\s*/);
    if (hLead) { hemi = hLead[1].toUpperCase(); s = s.substring(hLead[0].length).trim(); }
    var hTrail = s.match(/\s*([NSEWnsew])$/);
    if (hTrail) { hemi = hTrail[1].toUpperCase(); s = s.substring(0, s.length - hTrail[0].length).trim(); }
    var parts = s.split(/\s+/).map(Number);
    if (parts.length === 0 || parts.length > 3 || parts.some(isNaN)) return null;
    var decimal = Math.abs(parts[0]);
    if (parts.length >= 2) decimal += parts[1] / 60;
    if (parts.length >= 3) decimal += parts[2] / 3600;
    if (parts[0] < 0 || hemi === 'S' || hemi === 'W') decimal = -decimal;
    return decimal;
}

// Parses a "lat, lon" string in any degree format. Returns {lat, lon} or null.
function parseDegreeCoordPair(raw) {
    var norm = raw.replace(/°/g, ' ').replace(/'/g, ' ').replace(/"/g, ' ').replace(/\s+/g, ' ').trim();
    var commaIdx = norm.indexOf(',');
    if (commaIdx > 0) {
        var a = parseCoordPart(norm.substring(0, commaIdx));
        var b = parseCoordPart(norm.substring(commaIdx + 1));
        if (a !== null && b !== null) return { lat: a, lon: b };
    }
    return null;
}

// Quick-format helpers used by bigDialog to show GPS / screen-centre positions.
// Each reprojects a {x, y} source point and returns a formatted string.
// source.x/y are in the CRS given by `crs` (EPSG integer).

// Returns an Irish Grid reference string, or "" if out of range.
function justIG(source,crs){
var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),  CoordinateReferenceSystemUtils.fromDescription("EPSG:"+crs) , CoordinateReferenceSystemUtils.fromDescription("EPSG:29903"))
 return getIGFromXY(point.x, point.y)
 }

// Returns a UK National Grid reference string, or "" if out of range.
function justUKG(source,crs){
var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),  CoordinateReferenceSystemUtils.fromDescription("EPSG:"+crs) , CoordinateReferenceSystemUtils.fromDescription("EPSG:27700"))
 return getUKFromXY(point.x, point.y)
 }

// Returns a WGS84 "lat, lon" string rounded to the current decimals setting.
function justLL(source,crs){
var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),  CoordinateReferenceSystemUtils.fromDescription("EPSG:"+crs) , CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
if (appSettings.useNSEW)
    return Math.abs(point.y).toFixed(decimalsd.text) + (point.y >= 0 ? " N" : " S") + ",  " +
           Math.abs(point.x).toFixed(decimalsd.text) + (point.x >= 0 ? " E" : " W")
return ( point.y.toFixed(decimalsd.text)+", "+ point.x.toFixed(decimalsd.text) )  // y=lat, x=lon
 }

// Returns a WGS84 Degrees + Decimal Minutes string (lat / lon on separate lines).
function justDDM(source, crs) {
    var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),
        CoordinateReferenceSystemUtils.fromDescription("EPSG:" + crs),
        CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
    return decimalToDDM(point.y, true) + "\n" + decimalToDDM(point.x, false)
}

// Returns the best available grid reference for display in the BIG dialog:
// Irish Grid if enabled and in range, then UK Grid if enabled and in range, then DDM.
function bestGridRef(source, crs) {
    if (showIG.checked) { var ig = justIG(source, crs); if (ig !== "") return ig }
    if (showUK.checked) { var uk = justUKG(source, crs); if (uk !== "") return uk }
    return justDDM(source, crs)
}

 
 // Convert WGS84 lat/lon → MGRS string (uses QField projection + Mgrs grid math)
 function latLonToMgrs(lat, lon, precision) {
     var info = Mgrs.epsgForLatLon(lat, lon)
     if (!info) return ""
     var utmPt = GeometryUtils.reprojectPoint(
         GeometryUtils.point(lon, lat),
         CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"),
         CoordinateReferenceSystemUtils.fromDescription("EPSG:" + info.epsg))
     return Mgrs.utmToMgrs(info.zone, info.hemisphere, lat, utmPt.x, utmPt.y, precision !== undefined ? precision : 5)
 }

 // Convert MGRS string → {lat, lon} or null
 function mgrsToLatLon(mgrsStr) {
     var utm = Mgrs.mgrsToUtm(mgrsStr)
     if (!utm) return null
     var epsg = Mgrs.epsgForUtm(utm.zone, utm.hemisphere)
     var wgsPt = GeometryUtils.reprojectPoint(
         GeometryUtils.point(utm.easting, utm.northing),
         CoordinateReferenceSystemUtils.fromDescription("EPSG:" + epsg),
         CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
     if (!wgsPt || isNaN(wgsPt.y) || isNaN(wgsPt.x)) return null
     return { lat: wgsPt.y, lon: wgsPt.x }
 }

 // Formats a reprojected point.
 // Projected CRS: "X, Y" (easting, northing). Geographic CRS: "lat, lon", with N/S/E/W if toggle is on.
 function formatPoint(point, crs) {
 if (!crs.isGeographic) {
     return parseFloat(point.x.toFixed(decimalsm.text)) + ", " + parseFloat(point.y.toFixed(decimalsm.text))
 } else if (appSettings.useNSEW) {
     var latS = Math.abs(point.y).toFixed(decimalsd.text) + (point.y >= 0 ? " N" : " S")
     var lonS = Math.abs(point.x).toFixed(decimalsd.text) + (point.x >= 0 ? " E" : " W")
     return latS + ",  " + lonS
 } else {
     return parseFloat(point.y.toFixed(decimalsd.text)) + ", " + parseFloat(point.x.toFixed(decimalsd.text))
 }
 }


 // Returns the whole-minutes component of a decimal degree value (0–59).
 // Used to populate the DMS minute input boxes.
 function decimalToMinutes(decimal) {
if (typeof decimal !== 'number' || isNaN(decimal)) return ''
    var absDecimal = Math.abs(decimal);
    var degrees = Math.floor(absDecimal);
    return Math.floor((absDecimal - degrees) * 60);
}

 function decimalToDMss(decimal, isLat) {
if (typeof decimal !== 'number' || isNaN(decimal)) return ''
    var absDecimal = Math.abs(decimal);
    var degrees = Math.floor(absDecimal);
    var minutes = Math.floor((absDecimal - degrees) * 60);
    var seconds = ((absDecimal - degrees - minutes / 60) * 3600).toFixed(2);
    if (appSettings.useNSEW && isLat !== undefined) {
        var dir = isLat ? (decimal >= 0 ? "N" : "S") : (decimal >= 0 ? "E" : "W")
        return degrees + "° " + minutes + "' " + seconds + "\" " + dir
    }
    var sign = decimal < 0 ? "-" : "";
    return sign + degrees + "° " + minutes + "' " + seconds + "\""
}
 

}
