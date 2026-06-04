.pragma library

// What3Words — validation helper only.
// HTTP requests are made inline in the QML files (not here) because
// .pragma library files have restricted network access in Qt/QField.

// Return true if s looks like a three-word address (with or without ///).
function isValidWords(s) {
    s = (s || '').replace(/^\/\/\//, '').trim();
    // ASCII letters only — avoids Unicode range issues in QML JS engine
    return /^[a-zA-Z]+\.[a-zA-Z]+\.[a-zA-Z]+$/.test(s);
}
