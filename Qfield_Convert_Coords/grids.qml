import QtQuick
import org.qfield
import org.qgis

Item {
  signal prepareResult(var details)
  signal fetchResultsEnded()


  //Helper funcion to get IG 
function igtoWGS(input) {
   const string = input.replace(/\s/g, ''); // Remove all spaces from the input string
  if (typeof string !== 'string' || string.length !== 11) return false;
  const letter = string[0].toUpperCase();
  const numbers = string.slice(1); // Extract the remaining 10 characters
  if (
    !igletterMatrix.hasOwnProperty(letter) || // Check if the letter is in the IG matrix
    !/^\d{10}$/.test(numbers) // Check if the remaining characters are exactly 10 digits
  ) {
    return false;
       
  }
  // Extract the 5-digit easting and northing values
  const x5 = numbers.slice(0, 5); // First 5 digits (easting)
  const y5 = numbers.slice(5, 10); // Next 5 digits (northing)

  // Calculate the full easting (x6) and northing (y6)
  const x6 = parseInt(x5, 10) + (igletterMatrix[letter].first * 100000);
  const y6 = parseInt(y5, 10) + (igletterMatrix[letter].second * 100000);

  const pointGeometry = GeometryUtils.reprojectPoint(GeometryUtils.point(x6, y6), CoordinateReferenceSystemUtils.fromDescription("EPSG:29903"),  CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
  return pointGeometry;

}

  //Helper funcion to check UKG Validity
function uktoWGS(input) {
  const string = input.replace(/\s/g, ''); // Remove all spaces from the input string
  if (typeof string !== 'string' || string.length !== 12 ) return false;
  const letters = string.slice(0, 2).toUpperCase();
  const numbers = string.slice(2); // Extract the remaining 10 characters
  
  if (
    !ukletterMatrix.hasOwnProperty(letters) && // Check if the letter is in the UK matrix
    !/^\d{10}$/.test(numbers) // Check if the remaining characters are exactly 10 digits
  ){
    return false;
  }
  // Extract the 5-digit easting and northing values
  const x5 = numbers.slice(0, 5); // First 5 digits (easting)
  const y5 = numbers.slice(5, 10); // Next 5 digits (northing)
  const x6 = parseInt(x5, 10) + (ukletterMatrix[letters].first * 100000);
  const y6 = parseInt(y5, 10) + (ukletterMatrix[letters].second * 100000);
  const pointGeometry = GeometryUtils.reprojectPoint(GeometryUtils.point(x6, y6), CoordinateReferenceSystemUtils.fromDescription("EPSG:27700"),  CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
  return pointGeometry;
}

 function ddmToDecimal(coord) {
 if (!coord) return ''
 var parts = coord.split(/°|\s+/).filter(Boolean)
 var degrees = parseInt(parts[0], 10)
 var minutes = parts.length > 1 ? parseFloat(parts[1].replace("'", "")) : 0
 var decimal = degrees + (minutes / 60)
 return decimal.toFixed(6)
 }

function decimalToDDM(decimal) {
 if (typeof decimal !== 'number' || isNaN(decimal)) return ''
 
 var sign = decimal < 0 ? '-' : ''
 var absDecimal = Math.abs(decimal)
 
 var degrees = Math.floor(absDecimal)
 var minutes = (absDecimal - degrees) * 60
 
 return `${sign}${degrees}° ${minutes.toFixed(3)}'`
}

function fetchResults(string, context, parameters) {
  if (string === "") {
    fetchResultsEnded();
    return;
  }

  console.log('Processing input string....');

let details = {
  "userData": null,
  "displayString": string,
  "description": "desc.txt",
  "actions": [
    {
      "id": 1,
      "name": "Set as destination",
      "icon": "qrc:/themes/qfield/nodpi/ic_navigation_flag_purple_24dp.svg"
    },
    {
      "id": 2,
      "name": "Create a point",
      "icon": Qt.resolvedUrl("new.svg")
    }
  ]
};

  // Check if the input string is a valid Grid reference
  if (igtoWGS(string)) {
    const pointGeometry = igtoWGS(string); // Get the point geometry

    const stringcl = string.replace(/\s/g, ''); // Clean the input string
    const letter = stringcl.slice(0, 1).toUpperCase(); // Extract and uppercase the first letter
    const numbersa = stringcl.slice(1, 6); // Extract the next 5 characters
    const numbersb = stringcl.slice(6); // Extract the remaining 5 characters
    const inputstr = letter + " " + numbersa + " " + numbersb; // Reformat for output  const stringcl = string.replace(/\s/g, ''); //clean the input string
        
    details.displayString = pointGeometry.y.toFixed(5) + ", "+ pointGeometry.x.toFixed(5)  + " from Irish Grid: "+inputstr;
    details.userData = {
      geometry: pointGeometry, // Store the geometry in userData
      crs: "EPSG:4326" // Store the CRS
    };
    details.description = decimalToDDM(pointGeometry.y) + ", "+ decimalToDDM(pointGeometry.x) ;
  } else if (uktoWGS(string)) {
    const pointGeometry = uktoWGS(string); // Get the point geometry
    
    const stringcl = string.replace(/\s/g, ''); // Clean the input string
    const letter = stringcl.slice(0, 2).toUpperCase(); // Extract and uppercase the first 2 letters
    const numbersa = stringcl.slice(2, 7); // Extract the next 5 characters
    const numbersb = stringcl.slice(7); // Extract the remaining 5 characters
    const inputstr = letter + " " + numbersa + " " + numbersb; // Reformat for output  const stringcl = string.replace(/\s/g, ''); //clean the input string
    
    details.displayString = pointGeometry.y.toFixed(5) + ", "+ pointGeometry.x.toFixed(5)  + " from UK Grid: " + inputstr;
    details.userData = {
      geometry: pointGeometry, // Store the geometry in userData
      crs: "EPSG:4326" // Store the CRS
    };
    details.description = decimalToDDM(pointGeometry.y) + ", "+ decimalToDDM(pointGeometry.x) ;
      } else {
    details.displayString = string + " not valid Irish/UK Grid ref";
    details.description = " X 00000 00000 or XX 00000 00000 format expected";
  }

  prepareResult(details);
  fetchResultsEnded();

}




// Irish Grid letter matrix
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
    'U': { first: 4, second: 1 },
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

  // UK Grid letter matrix
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
    'HP': { first: 4, second: 12 }
  }

}
