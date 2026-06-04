.pragma library

// What3Words — validation helper only.
// HTTP requests are made inline in the QML files (not here) because
// .pragma library files have restricted network access in Qt/QField.

// Return true if s looks like a three-word address (with or without ///).
// Accepts dots (canonical: word.word.word) or spaces (word word word).
function isValidWords(s) {
    s = (s || '').replace(/^\/\/\//, '').trim();
    return /^[a-zA-Z]+[. ][a-zA-Z]+[. ][a-zA-Z]+$/.test(s);
}
