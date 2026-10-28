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
    property bool reorderable: false  // drag tiles to reorder (sourceModel must offer moveRow)

    readonly property bool isGrid: true
    property int current: -1          // row in sourceModel
    property bool keyboardNav: false

    readonly property int columns: menuView.columns
    readonly property int scrollBarSpace: vbar.size < 1 ? vbar.width + Kirigami.Units.smallSpacing : 0
    readonly property real cellWidth: Math.floor((width - scrollBarSpace) / columns)

    property var lines: []            // [{header: "A"} | {items: [row, …]}]
    property var order: []            // rows in display order
    property var positions: ({})      // row -> {line, col}
    property int dataRevision: 0      // bumped on rebuild so tiles re-read their row's data

    // Line geometry is known up front, so lines can tell whether they are near the viewport
    // before the ListView has positioned them
    readonly property font headerFont: Qt.font({
        family: Kirigami.Theme.defaultFont.family,
        pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15,
        weight: Font.DemiBold
    })
    readonly property int headerLineHeight: Math.ceil(headerMetrics.height) + Kirigami.Units.largeSpacing * 2
    readonly property var lineOffsets: {
        const offsets = [];
        let y = 0;
        for (const l of lines) {
            offsets.push(y);
            y += l.header !== undefined ? headerLineHeight : menuView.cellSize;
        }
        return offsets;
    }

    FontMetrics {
        id: headerMetrics
        font: view.headerFont
    }

    model: lines
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    topMargin: Kirigami.Units.largeSpacing
    bottomMargin: Kirigami.Units.largeSpacing
    reuseItems: false

    // Header lines are shorter than tile lines, so ListView would only estimate contentHeight
    // and the scrollbar would jump as it corrects itself. Keep every line instantiated so
    // the height is exact; lines only load their icons and labels once they come near the
    // viewport (see line.shown), which keeps this cheap.
    cacheBuffer: Math.max(menuView.cellSize * 3, lines.length * menuView.cellSize)

    PC3.ScrollBar.vertical: PC3.ScrollBar {
        id: vbar
    }

    // Smooth, even wheel/touchpad scrolling like Plasma's own scroll views
    Kirigami.WheelHandler {
        target: view
        filterMouseEvents: true
        keyNavigationEnabled: false
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
        dataRevision++;
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

    // ---- Reordering ----
    property int dragRow: -1
    property real dragX: 0
    property real dragY: 0
    property int dropIndex: -1        // insert before this display position
    property bool suppressClick: false

    function beginDrag(row) {
        dragRow = row;
        current = -1;
        interactive = false;
    }

    function updateDrag(x, y) {
        dragX = x;
        dragY = y;
        // Nudge the view when dragging near its edges
        const edge = menuView.cellSize / 3;
        if (y < edge) {
            contentY = Math.max(originY - topMargin, contentY - 8);
        } else if (y > height - edge) {
            contentY = Math.min(originY + contentHeight - height + bottomMargin, contentY + 8);
        }
        const lineIdx = indexAt(Math.min(x, cellWidth * columns - 1), y + contentY);
        if (lineIdx < 0) {
            dropIndex = y + contentY < originY ? 0 : order.length;
            return;
        }
        const items = lines[lineIdx].items;
        if (!items) {
            return;
        }
        // Dropping on a tile takes its place; past the end of a line goes after its last tile
        const col = Math.max(0, Math.floor(x / cellWidth));
        const from = order.indexOf(dragRow);
        if (col >= items.length) {
            dropIndex = order.indexOf(items[items.length - 1]) + 1;
        } else {
            const target = order.indexOf(items[col]);
            dropIndex = target > from ? target + 1 : target;
        }
    }

    function endDrag() {
        const from = order.indexOf(dragRow);
        if (from >= 0 && dropIndex >= 0) {
            const to = dropIndex > from ? dropIndex - 1 : dropIndex;
            if (to !== from) {
                sourceModel.moveRow(from, to);
            }
        }
        dragRow = -1;
        dropIndex = -1;
        interactive = true;
        suppressClick = true;
    }

    // Keyboard reordering (Ctrl+arrows) of the current tile
    function moveCurrentBy(step) {
        const from = order.indexOf(current);
        const to = from + step;
        if (!reorderable || from < 0 || to < 0 || to >= order.length) {
            return;
        }
        keyboardNav = true;
        sourceModel.moveRow(from, to);
        current = to;
        Qt.callLater(() => ensureVisible(current));
    }

    // Where the drop marker goes: left edge of the tile at dropIndex, or right edge of the last one
    function dropMarkerPos() {
        const from = order.indexOf(dragRow);
        if (dropIndex < 0 || order.length === 0 || dropIndex === from || dropIndex === from + 1) {
            return null;
        }
        const atEnd = dropIndex >= order.length;
        const row = order[atEnd ? order.length - 1 : dropIndex];
        const p = positions[row];
        const lineItem = p ? itemAtIndex(p.line) : null;
        if (!lineItem) {
            return null;
        }
        const pt = lineItem.mapToItem(view, (p.col + (atEnd ? 1 : 0)) * cellWidth, 0);
        return { x: pt.x, y: pt.y };
    }

    Rectangle {
        id: dropMarker
        readonly property var pos: view.dragRow >= 0 ? (view.contentY, view.dropIndex, view.dropMarkerPos()) : null
        visible: pos !== null
        z: 10
        x: pos ? pos.x - width / 2 : 0
        y: pos ? pos.y + view.menuView.cellSize * 0.15 : 0
        width: 3
        height: view.menuView.cellSize * 0.7
        radius: 1.5
        color: view.menuView.accent
    }

    Kirigami.Icon {
        id: dragGhost
        readonly property var entry: view.dragRow >= 0 ? view.dataAt(view.dragRow) : null
        visible: entry !== null
        z: 11
        width: Kirigami.Units.iconSizes.large
        height: width
        x: view.dragX - width / 2
        y: view.dragY - height / 2
        source: entry ? entry.decoration : ""
        opacity: 0.85
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
        required property int index
        readonly property bool isHeader: modelData.header !== undefined

        // Load tile contents once the line is within half a viewport of being visible;
        // once loaded it stays loaded so scrolling back doesn't reload icons
        property bool shown: false
        readonly property real lineTop: view.lineOffsets[index] ?? 0
        readonly property bool nearViewport: view.height > 0
            && lineTop + height >= view.contentY - view.height / 2
            && lineTop <= view.contentY + view.height * 1.5
        onNearViewportChanged: if (nearViewport) shown = true
        Component.onCompleted: if (nearViewport) shown = true

        function tileAt(col) {
            return tileRepeater.itemAt(col);
        }

        width: view.width - view.scrollBarSpace
        height: isHeader ? view.headerLineHeight : view.menuView.cellSize

        PC3.Label {
            id: headerLabel
            visible: line.isHeader
            anchors.left: parent.left
            anchors.leftMargin: Kirigami.Units.largeSpacing * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            text: line.modelData.header ?? ""
            color: view.menuView.accent
            font: view.headerFont
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
                    readonly property var item: (view.dataRevision, view.dataAt(row))
                    readonly property bool highlighted: view.dragRow < 0 && (containsMouse || (view.keyboardNav && view.current === row))
                    readonly property bool dragged: view.dragRow === row
                    property point pressPos

                    opacity: dragged ? 0.3 : 1
                    preventStealing: view.reorderable

                    width: view.cellWidth
                    height: view.menuView.cellSize
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    function openMenu(x, y) {
                        view.menuView.openContextMenu(tile, view.sourceModel, row, item ? item.actionList : null, item ? item.favoriteId : "", x, y);
                    }

                    onPressed: (mouse) => {
                        pressPos = Qt.point(mouse.x, mouse.y);
                        view.suppressClick = false;
                    }
                    onPositionChanged: (mouse) => {
                        if (!view.reorderable || !(mouse.buttons & Qt.LeftButton)) {
                            return;
                        }
                        const p = mapToItem(view, mouse.x, mouse.y);
                        if (view.dragRow < 0) {
                            if (Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) < Qt.styleHints.startDragDistance) {
                                return;
                            }
                            view.beginDrag(row);
                        }
                        view.updateDrag(p.x, p.y);
                    }
                    onReleased: {
                        if (view.dragRow >= 0) {
                            view.endDrag();
                        }
                    }
                    onCanceled: {
                        if (view.dragRow >= 0) {
                            view.dropIndex = -1;
                            view.endDrag();
                        }
                    }

                    onEntered: {
                        if (view.dragRow >= 0) {
                            return;
                        }
                        view.keyboardNav = false;
                        view.current = row;
                    }
                    onExited: {
                        if (!view.keyboardNav && view.current === row) {
                            view.current = -1;
                        }
                    }
                    onClicked: (mouse) => {
                        if (view.suppressClick) {
                            return;
                        }
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

                    Loader {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        active: line.shown
                        sourceComponent: tileContent
                    }

                    Component {
                        id: tileContent

                        ColumnLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                id: tileIcon
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                                source: tile.item ? tile.item.decoration : ""

                                // Optional hover lift/grow and press squeeze with a springy release
                                readonly property bool lifted: view.menuView.animateHover && tile.highlighted && !tile.pressed
                                readonly property bool squeezed: view.menuView.animateClick && tile.pressed
                                scale: squeezed ? 0.86 : (lifted ? 1.1 : 1)
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Kirigami.Units.longDuration
                                        easing.type: tile.pressed ? Easing.OutCubic : Easing.OutBack
                                        easing.overshoot: 2.5
                                    }
                                }
                                transform: Translate {
                                    y: tileIcon.lifted ? -Kirigami.Units.smallSpacing : 0
                                    Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                                }
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
}
