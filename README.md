# Convert Coordinates Dialogue

This is a plugin for the most excellent [Qfield](https://qfield.org/) app to convert between coordinates: Irish Grid, UK Grid, Lat long, Custom 1 (default=screen CRS) and Custom 2 (default = WGS84).

- Will show and convert screen centre coordinates, current GPS coordinates or manually inputted coordinates.
- Will create a point (in the active point layer) at location.
- Will pan or (on long press) zoom.
- Will navigate inside Qfield or (on long press) in google maps.
- Adds ability to search for and navigate to Irish grid or UK grid locations in the searchbar. Will give also give appropriate lat long as Decimal Degrees, Degrees + Decimal Minutes and Degrees, Minutes + Decimal seconds.
- Converted coodinates can be coped to the clipboard.
The basic screen shows Irish grid and Lat Longs. Coordinates can be grabbed from the screen centre (marked by a small crosshair)  or GPS, or you can type in.<br>

The UK grid system is also available, as are custom CRSs for when you go on holiday.... <n>By default the Custom 1 is set to the project CRS and Custom 2 is set to WGS84 (EPSG:4326). Custom  1 and 2 display and accept input in the form X,Y or Lon/Lat only. Their CRS can be set by inputting the appropriate [EPSG](https://epsg.io/) code & can be reset to default by using the <b>Reset</b> button in the options menu.

...Long pressing on buttons will give the alternative function... <b>Google</b> links to the location in your browser.

![image](https://github.com/user-attachments/assets/8295fd9d-85e9-4653-9a3f-5c62026c4a74)


You can change some of the outputs such as decimals displayed, text size and zoom level, toggle on or off the various CRSs or restore the original defaults....


## Search Irish UK Grid
It adds the ability to search for and navigate to Irish grid or UK grid locations in the searchbar.<br> It will give also give appropriate lat long as both Decimal Degrees and Degrees + Decimal Minutes. There is the option to *navigate* to the location and an option to *digitize* a point (in the active point layer) at location.<br>
Use the prefix 'grid' and enter a valid grid reference e.g. <b>V 99667 56878</b> for Irish Grid or <b>SE 58098 29345</b> for UK grid.

![image](https://github.com/user-attachments/assets/38fe92e9-844f-459f-9071-39f5d2ffbd8e)


