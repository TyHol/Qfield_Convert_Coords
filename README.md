# Convert Coordinates — QField Plugin

A plugin for the [QField](https://qfield.org/) mobile GIS app that converts between coordinate systems, creates points, and adds Irish/UK grid reference search to the QField locator bar.

> **Version:** 2.5.1 — 23 Apr 2026 | **Author:** Tyhol | **Repository:** https://github.com/TyHol/Qfield_Convert_Coords

---

## Contents

- [Installation](#installation)
- [Main Dialog](#main-dialog)
  - [Grabbing Coordinates](#grabbing-coordinates)
  - [Coordinate Formats](#coordinate-formats)
  - [Convert Button](#convert-button)
  - [CRS Picker](#crs-picker-custom-1--2)
  - [DMS Input Boxes](#dms-input-boxes)
  - [Action Buttons](#action-buttons)
  - [BIG Display](#big-display)
- [QR Code](#qr-code)
- [Canvas Menu Tools](#canvas-menu-tools)
- [Paste from Clipboard](#paste-from-clipboard)
- [Grid Reference Search](#grid-reference-search)
- [Snap Photo](#snap-photo)
- [Settings](#settings)
- [What's New in 2.5](#whats-new-in-25)

---

## Installation

Download the zip from the releases page and follow the QField plugin installation guide to install it.
Or scan this:
<img width="415" height="420" alt="Screenshot 2026-04-03 125157" src="https://github.com/user-attachments/assets/9bd6b878-f0a9-49f6-8164-5bffd8230ab9" />

---

## Main Dialog

Open the dialog by tapping the plugin button/icon in the QField toolbar.

![2 4 0](https://github.com/user-attachments/assets/feb48262-fbf2-4961-a3fa-18bb587b8408)

### Grabbing Coordinates

| Button | Action |
|---|---|
| **Screencenter** | Uses the map canvas centre point (indicated by the crosshair overlay) |
| **GPS** | Uses the current GPS position (GPS must be active) |
| **Type in** | Type directly into any coordinate box, then tap **Convert** |
| **Paste** | Paste a coordinate from the clipboard |

### Coordinate Formats

Each row can be shown or hidden in Settings.

| Row | Format | Example | Input? |
|---|---|---|---|
| **Irish Grid** | Letter + 5-digit easting + 5-digit northing (EPSG:29903) | `H 54321 89797` | Yes |
| **UK Grid** | Two letters + 5-digit easting + 5-digit northing (EPSG:27700) | `NS 45140 72887` | Yes |
| **Custom 1** | X, Y in any CRS — EPSG selectable via picker | `313621, 234156` | Yes |
| **Custom 2** | X, Y in a second custom CRS | `53.3498, -6.2603` | Yes |
| **WGS84** | Latitude, Longitude in decimal degrees | `53.34980, -6.26031` | Yes |
| **WGS84 DDM** | Degrees + Decimal Minutes | `53° 20.988' N, 6° 15.619' W` | Yes |
| **WGS84 DMS** | Degrees, Minutes, Decimal Seconds | `53° 20' 59.28" N, 6° 15' 37.11" W` | Yes |
| **MGRS** | Military Grid Reference System | `29U MV 12345 67890` | Yes |
| **Plus Code** | Open Location Code (Google Plus Codes) | `9C5P37C3+45J` | Yes |

Each row has a **copy** button that copies the displayed value to the clipboard.

### Convert Button

A prominent green **Convert** button is the single trigger for all conversions. After editing any coordinate box, tap Convert to update all other rows. Copy buttons and the BIG dialog will auto-convert if needed before running.

### CRS Picker (Custom 1 & 2)

The Custom 1 and 2 EPSG fields have an autocomplete picker built in:

- **Type** a code or name to filter — results appear immediately on desktop, or tap **…** to open the picker on Android/iOS
- **70+ presets** covering Ireland, UK, ETRS89 UTM zones 26–38, WGS84 UTM, and national grids across Europe
- Free-text entry still works for any EPSG code not in the list
- Selected CRS is **saved between sessions** — no need to re-enter after restarting QField

> **Accuracy note:** When converting to/from British National Grid (27700) or Irish Grid (29903/29902), a toast warning appears if PROJ grid shift files (OSTN15/OSTNI15) are not installed — accuracy in that case is ~3–5m (BNG) or ~1–3m (Irish Grid) rather than sub-metre. The warning shows once per CRS selection.

### DMS Input Boxes

Six editable boxes for entering Degrees, Minutes and Seconds separately for latitude and longitude. Tap **Convert** to push the DMS values into all other rows.

### N/S/E/W Labels

A checkbox in Settings toggles between `N/S/E/W` directional labels and `+/−` signs on DDM and DMS output.

### Action Buttons

Up to six buttons appear in the "Do:" row — each can be shown or hidden in Settings. With all six visible they wrap to two rows of three.

| Button | Action |
|---|---|
| **Pan** | Pans the map canvas to the coordinate |
| **Zoom** | Zooms to the coordinate |
| **Add** | Adds a point to the selected layer |
| **Navigate** | Sets QField navigation destination |
| **Web** | Opens in the chosen external map app |
| **BIG** | Tap: BIG display (GPS + screen centre) / Long press: BIG display (all values) |

### BIG Display

Two large-text overlay dialogs for easy reading in the field:

- **BIG (tap):** Shows current GPS position and screen centre in Irish Grid / UK Grid and Lat/Long.
- **BIG (long press):** Shows all current values from the main dialog text boxes.

Tap any value in either BIG dialog to copy it to the clipboard.

---

## QR Code

Two buttons appear below the WGS84 row (can be hidden in Settings):

| Button | Function |
|---|---|
| **Show QR** | Generates a `geo:lat,lon` QR code from the current coordinates |
| **Scan QR** | Opens the device camera to scan a QR code containing a coordinate |

Inside the QR dialog:

| Button | Function |
|---|---|
| **Copy URI** | Copies the `geo:lat,lon` URI to the clipboard |
| **Share Image** | Saves the QR code as an image and opens the system share sheet |

Scanned QR codes containing `geo:` URIs are automatically parsed and loaded into the main dialog — the same confirm dialog as a normal paste applies.

---

## Canvas Menu Tools

Long-press on the map canvas to access:

| Item | Tap | Long press |
|---|---|---|
| **Copy link / hold to open map** | Copies a shareable map link to the clipboard (paste into WhatsApp, SMS, etc.) | Opens tapped location in external map app |
| **Add point** | Adds a point at the tapped location | — |
| **Convert coordinates** | Opens main dialog pre-loaded with tapped location | — |
| **Paste location from clipboard** | Parses clipboard as a coordinate, creates a point and zooms to it | — |

The **Web** button in the main dialog follows the same tap/hold behaviour: tap to copy the link, long-press to open in the external map app.

---

## Paste from Clipboard

Accepts a wide range of coordinate formats:

| Format | Example |
|---|---|
| Irish Grid | `H 54321 89797` or `H5432189797` |
| UK Grid | `NS 45140 72887` or `NS4514072887` |
| WGS84 decimal degrees | `53.3498, -6.2603` |
| WGS84 DDM | `53° 20.988' N, 6° 15.619' W` |
| WGS84 DMS | `53° 20' 59" N, 6° 15' 37" W` |
| MGRS | `29U MV 12345 67890` |
| Plus Code | `9C5P37C3+45J` |
| WKT Point | `POINT (84092.667 53131.478)` or a full feature info block containing a Point geometry (pastes point only - not attributes) |
| Projected coordinates | `313621, 234156` |
| geo: URI | `geo:53.3498,-6.2603` |

A **Confirm coordinate format** dialog appears before anything is committed, showing the parsed text and the resulting coordinates. Tap **Apply** to accept or **Cancel** to abort.

For **WKT Point** pastes, a **Select CRS** step appears first — choose from Project CRS, Layer CRS, Custom 1, or Custom 2. The coordinates are then reprojected to WGS84 and passed through the normal confirm dialog.

---

## Snap Photo

The Snap Photo feature adds a dedicated camera toolbar button that instantly captures a GPS-positioned photo and saves it as a new point feature — without having to open the main plugin dialog. It is based almost entirely on https://github.com/opengisch/qfield-snap

### Enabling

Go to **Settings → Load tab** and tick **Snap photo button**, then restart QField. A camera icon will appear in the toolbar alongside the main plugin button.

### Using

**Tap** the snap button to open the device camera immediately (GPS must be active and returning a valid position). On completing the photo:

- The image is saved to a `DCIM/` folder inside the project directory with a timestamp filename.
- A new point feature is created at the current GPS position on the configured target layer.
- The photo path is written to the configured photo field.
- The feature form opens so you can fill in any other attributes.

**Long-press** the snap button at any time to open the **Snap settings tab** directly.

### Setup (Snap tab in Settings)

| Setting | Description |
|---|---|
| **Target layer** | Which point layer to add features to. Defaults to the active layer. |
| **Photo field** | Which text field to write the photo path into. Auto-detected from common names (`photo`, `picture`, `image`, `media`, `camera`). |
| **Reset to defaults** | Restores the layer and field selections to the factory defaults. |

If no layer or field is explicitly selected the plugin falls back to the active layer and searches field names in the order: `photo`, `picture`, `image`, `media`, `camera`.

---

## Grid Reference Search

Type the prefix **`grid`** in the QField search bar followed by a grid reference:

```
grid H 54321 89797      ← Irish Grid
grid SE 58098 29345     ← UK Grid
grid NS4514072887       ← spaces not required
```

Results show the reference converted to Decimal Degrees and DDM, with options to **Navigate** or **Add point**.

![image](https://github.com/user-attachments/assets/38fe92e9-844f-459f-9071-39f5d2ffbd8e)

---

## Settings

Open by tapping **⚙** in the main dialog header or long-pressing the plugin toolbar button.

### Add points to
Selects the target layer — lists all editable point layers in the current project.

### After adding point

| Option | Effect |
|---|---|
| Don't zoom/pan | Map view stays put |
| Pan to | Pans to the new point |
| Zoom to | Zooms to the new point |
| Show form on add | Opens attribute form for each new point |

Zoom extent presets: Detail (~25m), Building (~50m), Street (~500m), Town (~2km), Region (~20km), Country (~200km).

### Display
Toggle visibility of each coordinate row, DMS boxes, the map crosshair, and the QR Buttons row.

### Action Buttons
Show or hide any of the six action buttons individually: Pan, Zoom, Add, Navigate, Web, BIG.

### N/S/E/W labels
Toggle between directional labels and +/− signs on DDM/DMS output.

### External map
Choose which app opens on Navigate/Web long-press: Google Maps (pin), Google Maps (nav), OpenStreetMap, or OSRM routing.

### Format
Font size, decimal places for projected coordinates, and decimal places for geographic coordinates.

### Reset
Restores all settings and CRS codes to defaults (Custom 1 → project CRS, Custom 2 → EPSG:4326).

---

*All settings and CRS selections are persisted between sessions.*

---

## What's New in 2.5

### Snap Photo (new feature)
Integrated the standalone `qfield-snap` plugin directly into Convert Coordinates. A camera toolbar button captures a GPS-positioned photo and creates a point feature in one tap. Enable it on the **Load** tab; configure layer and field on the new **Snap** tab in Settings.

### Copy link from canvas / Web button
The **Copy link / hold to open map** canvas menu item and the **Web** button in the main dialog now have split tap/hold behaviour: a short tap copies a shareable map URL to the clipboard (ready to paste into WhatsApp, SMS, email, etc.), while a long press opens the location in the external map app as before.
