import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ListView {
    id: list

    required property Item menuView
    property string placeholder
    property bool defaultFirst: false   // Enter launches the first row when nothing is selected
    readonly property bool isGrid: false
    property bool keyboardNav: false
    readonly property int scrollBarSpace: vbar.size < 1 ? vbar.width + Kirigami.Units.smallSpacing : 0

    clip: true
    currentIndex: -1
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    topMargin: Kirigami.Units.largeSpacing
    bottomMargin: Kirigami.Units.largeSpacing
    spacing: 2

    PC3.ScrollBar.vertical: PC3.ScrollBar {
        id: vbar
    }

    function reset() {
        currentIndex = -1;
        keyboardNav = false;
        positionViewAtBeginning();
    }

    function activate() {
        const row = currentIndex >= 0 ? currentIndex : (defaultFirst ? 0 : -1);
        if (row >= 0 && row < count) {
            menuView.launch(model, row);
        }
    }

    function moveKey(key) {
        if (count === 0) {
            return;
        }
        keyboardNav = true;
        if (key === Qt.Key_Down) {
            currentIndex = Math.min(count - 1, currentIndex + 1);
        } else if (key === Qt.Key_Up) {
            currentIndex = Math.max(0, currentIndex - 1);
        }
        positionViewAtIndex(currentIndex, ListView.Contain);
    }

    function openCurrentContextMenu() {
        if (currentItem) {
            currentItem.openMenu(currentItem.width / 2, currentItem.height / 2);
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: list.count === 0 && text !== ""
        iconName: "edit-find-symbolic"
        text: list.placeholder
    }

    delegate: MouseArea {
        id: row

        required property int index
        required property var model
        readonly property bool highlighted: containsMouse || (list.keyboardNav && ListView.isCurrentItem)

        width: list.width - list.scrollBarSpace
        height: content.implicitHeight + Kirigami.Units.largeSpacing * 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        function openMenu(x, y) {
            list.menuView.openContextMenu(row, list.model, index, model.actionList, x, y);
        }

        onEntered: {
            list.keyboardNav = false;
            list.currentIndex = index;
        }
        onExited: {
            if (!list.keyboardNav && list.currentIndex === index) {
                list.currentIndex = -1;
            }
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                openMenu(mouse.x, mouse.y);
            } else {
                list.menuView.launch(list.model, index);
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 2
            color: Kirigami.Theme.textColor
            opacity: row.highlighted ? (row.pressed ? 0.12 : 0.07) : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }

        RowLayout {
            id: content
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: row.model.decoration
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PC3.Label {
                    Layout.fillWidth: true
                    text: row.model.display ?? ""
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text !== "" && text !== row.model.display
                    text: row.model.description ?? ""
                    elide: Text.ElideMiddle
                    opacity: 0.65
                    font: Kirigami.Theme.smallFont
                }
            }
        }
    }
}
