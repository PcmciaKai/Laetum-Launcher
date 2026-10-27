import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// A grid of app tiles laid out as a list of lines, so lines can be
// either a row of tiles or (when sectioned) an A/B/C… header.
ListView {
    id: view

    required property Item menuView
    property var sourceModel
    property bool sectioned: false
    property string placeholder
    property string placeholderExplanation

    readonly property bool isGrid: true
    property int current: -1          // row in sourceModel
    property bool keyboardNav: false

    readonly property int columns: menuView.columns
    readonly property int scrollBarSpace: vbar.size < 1 ? vbar.width + Kirigami.Units.smallSpacing : 0
    readonly property real cellWidth: Math.floor((width - scrollBarSpace) / columns)

    property var lines: []            // [{header: "A"} | {items: [row, …]}]
    property var order: []            // rows in display order
    property var positions: ({})      // row -> {line, col}

    model: lines
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    topMargin: Kirigami.Units.largeSpacing
    bottomMargin: Kirigami.Units.largeSpacing
    reuseItems: false

    PC3.ScrollBar.vertical: PC3.ScrollBar {
        id: vbar
    }

    function dataAt(row) {
        const o = rows.objectAt(row);
        return o ? o.model : null;
    }

    function letterFor(name) {
        const first = String(name ?? "").normalize("NFD").charAt(0).toLocaleUpperCase();
        return first.toLocaleLowerCase() !== first ? first : "#";
    }

    function rebuild() {
        const out = [];
        const ord = [];
        const pos = {};
        const push = (items) => {
            for (let i = 0; i < items.length; i += columns) {
                const chunk = items.slice(i, i + columns);
                chunk.forEach((r, c) => {
                    pos[r] = { line: out.length, col: c };
                    ord.push(r);
                });
                out.push({ items: chunk });
            }
        };

        const all = [];
        for (let i = 0; i < rows.count; ++i) {
            all.push(i);
        }

        if (sectioned) {
            const groups = new Map();
            for (const r of all) {
                const d = dataAt(r);
                const l = letterFor(d ? d.display : "");
                if (!groups.has(l)) {
                    groups.set(l, []);
                }
                groups.get(l).push(r);
            }
            const letters = [...groups.keys()].sort((a, b) => a === "#" ? -1 : b === "#" ? 1 : a.localeCompare(b));
            for (const l of letters) {
                out.push({ header: l });
                push(groups.get(l));
            }
        } else {
            push(all);
        }

        order = ord;
        positions = pos;
        lines = out;
    }

    function scheduleRebuild() {
        rebuildTimer.restart();
    }

    onColumnsChanged: scheduleRebuild()
    onSectionedChanged: scheduleRebuild()

    Timer {
        id: rebuildTimer
        interval: 0
        onTriggered: view.rebuild()
    }

    Instantiator {
        id: rows
        model: view.sourceModel
        delegate: QtObject {
            required property var model
            required property int index
        }
        onObjectAdded: view.scheduleRebuild()
        onObjectRemoved: view.scheduleRebuild()
    }

    Connections {
        target: view.sourceModel
        ignoreUnknownSignals: true
        function onRowsMoved() {
            view.scheduleRebuild();
        }
        function onModelReset() {
            view.scheduleRebuild();
        }
    }

    function reset() {
        current = -1;
        keyboardNav = false;
        positionViewAtBeginning();
    }

    function ensureVisible(row) {
        const p = positions[row];
        if (!p) {
            return;
        }
        if (p.line > 0 && lines[p.line - 1].header !== undefined) {
            positionViewAtIndex(p.line - 1, ListView.Contain);
        }
        positionViewAtIndex(p.line, ListView.Contain);
    }

    function moveKey(key) {
        if (order.length === 0) {
            return;
        }
        keyboardNav = true;
        const p = positions[current];
        if (!p) {
            current = order[0];
        } else if (key === Qt.Key_Left || key === Qt.Key_Right) {
            const i = order.indexOf(current) + (key === Qt.Key_Right ? 1 : -1);
            current = order[Math.max(0, Math.min(order.length - 1, i))];
        } else {
            const dir = key === Qt.Key_Down ? 1 : -1;
            let l = p.line + dir;
            while (l >= 0 && l < lines.length && !lines[l].items) {
                l += dir;
            }
            if (l >= 0 && l < lines.length) {
                const items = lines[l].items;
                current = items[Math.min(p.col, items.length - 1)];
            }
        }
        ensureVisible(current);
    }

    function activate() {
        if (current >= 0) {
            menuView.launch(sourceModel, current);
        }
    }

    function tileFor(row) {
        const p = positions[row];
        const line = p ? itemAtIndex(p.line) : null;
        return line ? line.tileAt(p.col) : null;
    }

    function openCurrentContextMenu() {
        const tile = tileFor(current);
        if (tile) {
            tile.openMenu(tile.width / 2, tile.height / 2);
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: rows.count === 0 && text !== ""
        iconName: "view-app-grid-symbolic"
        text: view.placeholder
        explanation: view.placeholderExplanation
    }

    delegate: Item {
        id: line

        required property var modelData
        readonly property bool isHeader: modelData.header !== undefined

        function tileAt(col) {
            return tileRepeater.itemAt(col);
        }

        width: view.width - view.scrollBarSpace
        height: isHeader ? headerLabel.implicitHeight + Kirigami.Units.largeSpacing * 2 : view.menuView.cellSize

        PC3.Label {
            id: headerLabel
            visible: line.isHeader
            anchors.left: parent.left
            anchors.leftMargin: Kirigami.Units.largeSpacing * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            text: line.modelData.header ?? ""
            color: view.menuView.accent
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
        }

        Rectangle {
            visible: line.isHeader
            anchors.left: headerLabel.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.right: parent.right
            anchors.rightMargin: Kirigami.Units.largeSpacing
            anchors.verticalCenter: headerLabel.verticalCenter
            height: 1
            color: view.menuView.hairline
        }

        Row {
            visible: !line.isHeader

            Repeater {
                id: tileRepeater
                model: line.modelData.items ?? []

                MouseArea {
                    id: tile

                    required property int modelData
                    readonly property int row: modelData
                    readonly property var item: view.dataAt(row)
                    readonly property bool highlighted: containsMouse || (view.keyboardNav && view.current === row)

                    width: view.cellWidth
                    height: view.menuView.cellSize
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    function openMenu(x, y) {
                        view.menuView.openContextMenu(tile, view.sourceModel, row, item ? item.actionList : null, item ? item.favoriteId : "", x, y);
                    }

                    onEntered: {
                        view.keyboardNav = false;
                        view.current = row;
                    }
                    onExited: {
                        if (!view.keyboardNav && view.current === row) {
                            view.current = -1;
                        }
                    }
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            openMenu(mouse.x, mouse.y);
                        } else {
                            view.menuView.launch(view.sourceModel, row);
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.cornerRadius * 2
                        color: Kirigami.Theme.textColor
                        opacity: tile.highlighted ? (tile.pressed ? 0.12 : 0.07) : 0
                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.large
                            Layout.preferredHeight: Kirigami.Units.iconSizes.large
                            source: tile.item ? tile.item.decoration : ""
                            scale: tile.pressed ? 0.9 : 1
                            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                        }

                        PC3.Label {
                            Layout.fillWidth: true
                            text: tile.item ? (tile.item.display ?? "") : ""
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
