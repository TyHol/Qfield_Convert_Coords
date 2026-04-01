import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "crs_presets.js" as CrsPresets

// CRS picker: type a code directly, or tap … to open a filtered dropdown.
// On Android, the dropdown must be opened by a touch event (the … button).
// Once open, typing in the code field updates the list live.
// Exposes:  property string text        — EPSG code (read/write)
//           property string placeholderText
//           property real   fieldFontSize
//           property var    recentCodes  — array of recently used codes (max 3), shown at top

Item {
    id: root
    implicitHeight: 35
    implicitWidth:  100

    // ── Public API ──────────────────────────────────────────────────────────
    property string text: ""
    property string placeholderText: "EPSG"
    property real   fieldFontSize: 12

    // ── Sync flags ──────────────────────────────────────────────────────────
    property bool _fromRoot:  false
    property bool _fromInput: false

    onTextChanged: {
        if (_fromInput) return
        _fromRoot = true
        if (codeField.text !== root.text) codeField.text = root.text
        _fromRoot = false
        dropPopup.close()
        dropModel.clear()
    }

    // ── Lookup name for a code ───────────────────────────────────────────────
    function _nameForCode(code) {
        for (var i = 0; i < CrsPresets.list.length; i++)
            if (CrsPresets.list[i].code === code) return CrsPresets.list[i].name
        return "Custom (" + code + ")"
    }

    // ── Filter (updates model; only opens popup if already visible) ──────────
    function _filter(query) {
        dropModel.clear()
        var q = query.toLowerCase().trim()

        if (q.length === 0) {
            for (var i = 0; i < CrsPresets.list.length; i++)
                dropModel.append({name: CrsPresets.list[i].name, code: CrsPresets.list[i].code, isHeader: false})
            return
        }
        for (var j = 0; j < CrsPresets.list.length; j++) {
            var item = CrsPresets.list[j]
            if (item.code.indexOf(q) !== -1 || item.name.toLowerCase().indexOf(q) !== -1)
                dropModel.append({name: item.name, code: item.code, isHeader: false})
        }
    }

    // ── Layout: code field + … button ───────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 2

        TextField {
            id: codeField
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: root.placeholderText
            font.pixelSize: root.fieldFontSize
            font.family:    "Arial"
            font.bold:      true
            font.italic:    true

            onTextChanged: {
                if (root._fromRoot) return
                root._fromInput = true
                if (root.text !== text) root.text = text
                root._fromInput = false
                if (dropPopup.visible) {
                    root._filter(text)
                } else if (["windows","osx","linux","unix"].indexOf(Qt.platform.os) !== -1) {
                    root._filter(text)
                    if (dropModel.count > 0) dropPopup.open()
                }
            }
        }

        Button {
            visible: ["windows","osx","linux","unix"].indexOf(Qt.platform.os) === -1
            Layout.preferredWidth:  visible ? 30 : 0
            Layout.preferredHeight: 30
            padding: 0
            text: "…"
            font.pixelSize: 16
            font.bold: true
            background: Rectangle {
                color:  parent.pressed ? "#6aaa20" : "#80CC28"
                radius: 4
            }
            contentItem: Text {
                text:  parent.text
                color: "white"
                font:  parent.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
            }
            onClicked: {
                if (dropPopup.visible) {
                    dropPopup.close()
                } else {
                    root._filter(codeField.text)
                    dropPopup.open()
                }
            }
        }
    }

    ListModel { id: dropModel }

    // ── Dropdown Popup ───────────────────────────────────────────────────────
    Popup {
        id: dropPopup
        parent:      root.parent ? root.parent : root
        x:           0
        y:           root.y + root.height + 2
        width:       root.parent ? root.parent.width : 300
        padding:     0
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            color:        "#FFFFFF"
            border.color: "#80CC28"
            border.width: 1
            radius:       4
        }

        contentItem: ListView {
            id: dropList
            model:          dropModel
            clip:           true
            implicitHeight: Math.min(dropModel.count, 8) * 44

            delegate: Rectangle {
                width:  dropList.width
                height: model.isHeader ? 28 : 44
                color:  model.isHeader ? "#f0f0f0" : (rowMouse.containsMouse ? "#e8f8c8" : "#FFFFFF")

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:        parent.left
                    anchors.right:       parent.right
                    anchors.leftMargin:  8
                    anchors.rightMargin: 4
                    text:       model.isHeader ? model.name : (model.name + "  (" + model.code + ")")
                    font.pixelSize: model.isHeader ? 10 : 12
                    font.family:    "Arial"
                    font.bold:      model.isHeader
                    color:      model.isHeader ? "#888888" : "#222222"
                    elide:      Text.ElideRight
                }

                Rectangle {
                    visible:        !model.isHeader
                    anchors.bottom: parent.bottom
                    width:  parent.width
                    height: 1
                    color:  "#dddddd"
                }

                MouseArea {
                    id:          rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled:     !model.isHeader
                    onClicked: {
                        root._fromRoot = true
                        root.text      = model.code
                        codeField.text = model.code
                        root._fromRoot = false
                        dropPopup.close()
                    }
                }
            }
        }
    }
}
