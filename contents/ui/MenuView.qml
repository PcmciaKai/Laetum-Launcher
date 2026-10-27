import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.sessions as Sessions
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCMUtils
import org.kde.kirigamiaddons.components as KAComponents

FocusScope {
    id: menu

    readonly property int columns: Math.max(3, Plasmoid.configuration.columns)
    readonly property int cellSize: Kirigami.Units.gridUnit * 6
    readonly property int pad: Kirigami.Units.gridUnit

    Layout.preferredWidth: columns * cellSize + pad * 3
    Layout.minimumWidth: Layout.preferredWidth
    Layout.preferredHeight: Kirigami.Units.gridUnit * 30
    Layout.minimumHeight: Kirigami.Units.gridUnit * 24

    // Tabs: Pinned, optional Recent, All Apps, then any categories picked in settings
    readonly property var tabs: {
        const t = [{ kind: "pinned", label: i18n("Pinned") }];
        if (Plasmoid.configuration.showRecent) {
            t.push({ kind: "recent", label: i18n("Recent") });
        }
        t.push({ kind: "all", label: i18n("All Apps") });
        const wanted = Plasmoid.configuration.categoryTabs;
        for (const c of root.categories) {
            if (wanted.includes(c.label)) {
                t.push({ kind: "category", label: c.label, row: c.row });
            }
        }
        return t;
    }
    property int currentTab: 0
    readonly property var tab: tabs[Math.min(currentTab, tabs.length - 1)]
    readonly property bool searching: root.searchText.length > 0
    readonly property var tabViews: ({ pinned: pinnedView, recent: recentView, all: appsView, category: categoryView })
    readonly property var activeView: searching ? resultsView : tabViews[tab.kind]

    readonly property color accent: root.accentColor
    readonly property color hairline: Qt.alpha(Kirigami.Theme.textColor, 0.12)
    readonly property color headerColor: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.08)

    function defaultTabIndex() {
        const kind = ["pinned", "recent", "all"][Plasmoid.configuration.defaultTab] ?? "pinned";
        return Math.max(0, tabs.findIndex(t => t.kind === kind));
    }

    function reset() {
        searchField.text = "";
        currentTab = defaultTabIndex();
        for (const v of [pinnedView, recentView, appsView, categoryView, resultsView]) {
            v.reset();
        }
        searchField.forceActiveFocus();
    }

    function launch(model, row) {
        if (!model || row < 0) {
            return;
        }
        model.trigger(row, "", null);
        root.expanded = false;
    }

    function run(command) {
        executable.connectSource(command);
        root.expanded = false;
    }

    // Launch by desktop file ID if one exists (e.g. org.dnf.AppCenter), otherwise as a command (e.g. dnf-app-center)
    function runApp(id) {
        const quoted = "'" + String(id).replace(/'/g, "'\\''") + "'";
        run("sh -c 'for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" $(echo \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr : \" \"); do "
            + "[ -e \"$d/applications/$0.desktop\" ] && exec kstart --application \"$0\"; done; exec kstart -- \"$0\"' " + quoted);
    }

    // ---- Context menu, built from the model's actionList like Kickoff does ----
    property var menuModel: null
    property int menuIndex: -1

    // Kickoff adds Pin/Unpin itself rather than relying on the model's actionList
    function favoriteActions(favoriteId) {
        const favorites = root.rootModel.favoritesModel;
        if (!favorites || !favoriteId) {
            return [];
        }
        return favorites.isFavorite(favoriteId)
            ? [{ text: i18n("Remove from Favorites"), icon: "list-remove", actionId: "_kicker_favorite_remove", actionArgument: favoriteId }]
            : [{ text: i18n("Add to Favorites"), icon: "bookmark-new", actionId: "_kicker_favorite_add", actionArgument: favoriteId }];
    }

    function triggerAction(actionId, actionArgument) {
        if (actionId === "_kicker_favorite_add") {
            root.rootModel.favoritesModel.addFavorite(actionArgument);
        } else if (actionId === "_kicker_favorite_remove") {
            root.rootModel.favoritesModel.removeFavorite(actionArgument);
        } else if (menuModel && menuModel.trigger(menuIndex, actionId, actionArgument)) {
            root.expanded = false;
        }
    }

    function openContextMenu(visualParent, model, index, actionList, favoriteId, x, y) {
        const favorites = favoriteActions(favoriteId);
        const others = (actionList || []).filter(a => !String(a.actionId ?? "").startsWith("_kicker_favorite_"));
        if (favorites.length > 0 && others.length > 0) {
            favorites.push({ type: "separator" });
        }
        actionList = favorites.concat(others);
        if (actionList.length === 0) {
            return;
        }
        menuModel = model;
        menuIndex = index;
        contextMenu.clearMenuItems();
        const add = (items) => {
            for (const a of items) {
                if (a.subActions) {
                    menuItemComponent.createObject(contextMenu, { actionItem: { type: "title", text: a.text } });
                    add(a.subActions);
                } else {
                    menuItemComponent.createObject(contextMenu, { actionItem: a });
                }
            }
        };
        add(actionList);
        contextMenu.visualParent = visualParent;
        contextMenu.open(x, y);
    }

    PlasmaExtras.Menu {
        id: contextMenu
    }

    Component {
        id: menuItemComponent
        PlasmaExtras.MenuItem {
            property var actionItem
            text: actionItem.text ?? ""
            icon: actionItem.icon ?? null
            separator: actionItem.type === "separator"
            section: actionItem.type === "title"
            enabled: actionItem.type !== "title" && (actionItem.enabled ?? true)
            checkable: actionItem.checkable ?? false
            checked: actionItem.checked ?? false
            onClicked: menu.triggerAction(actionItem.actionId, actionItem.actionArgument)
        }
    }

    // ---- Helpers ----
    KCoreAddons.KUser {
        id: kuser
    }

    Sessions.SessionManagement {
        id: session
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                menu.reset();
            }
        }
    }

    Component.onCompleted: reset()

    // ---- Layout ----
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header: opaque band that reaches the popup's edges
        Item {
            id: header
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + Math.round(menu.pad * 1.5)

            Kirigami.ShadowedRectangle {
                readonly property real cornerRadius: Plasmoid.location === PlasmaCore.Types.TopEdge ? 0 : Kirigami.Units.cornerRadius
                x: -menu.Kirigami.ScenePosition.x
                y: -menu.Kirigami.ScenePosition.y
                width: menu.Window.window ? menu.Window.width : header.width
                height: header.height - y
                color: menu.headerColor
                corners.topLeftRadius: cornerRadius
                corners.topRightRadius: cornerRadius
                corners.bottomLeftRadius: 0
                corners.bottomRightRadius: 0
            }

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.leftMargin: menu.pad
                anchors.rightMargin: menu.pad
                spacing: Kirigami.Units.largeSpacing

                KAComponents.Avatar {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                    source: kuser.faceIconUrl
                    name: kuser.fullName || kuser.loginName

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            KCMUtils.KCMLauncher.openSystemSettings("kcm_users");
                            root.expanded = false;
                        }
                    }
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: kuser.fullName || kuser.loginName
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
                    elide: Text.ElideRight
                }

                HeaderButton {
                    visible: Plasmoid.configuration.storeApp !== ""
                    iconName: "amarok_cart_view-symbolic"
                    tooltip: i18n("Software Store")
                    onClicked: menu.runApp(Plasmoid.configuration.storeApp)
                }
                HeaderButton {
                    iconName: "folder-symbolic"
                    tooltip: i18n("Files")
                    onClicked: {
                        Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.HomeLocation));
                        root.expanded = false;
                    }
                }
                HeaderButton {
                    visible: Plasmoid.configuration.terminalApp !== ""
                    iconName: "utilities-terminal-symbolic"
                    tooltip: i18n("Terminal")
                    onClicked: menu.runApp(Plasmoid.configuration.terminalApp)
                }
                HeaderButton {
                    iconName: "configure-symbolic"
                    tooltip: i18n("System Settings")
                    onClicked: {
                        KCMUtils.KCMLauncher.openSystemSettings("");
                        root.expanded = false;
                    }
                }
                HeaderButton {
                    id: powerButton
                    iconName: "system-shutdown-symbolic"
                    tooltip: i18n("Power")
                    onClicked: powerMenu.openRelative()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: menu.hairline
        }

        // Tabs with a sliding accent indicator sitting on the hairline
        ListView {
            id: tabList
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(menu.width - menu.pad * 2, contentWidth)
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
            orientation: ListView.Horizontal
            spacing: Kirigami.Units.smallSpacing
            clip: true
            interactive: contentWidth > width
            boundsBehavior: Flickable.StopAtBounds
            model: menu.tabs
            currentIndex: menu.currentTab
            highlightMoveDuration: Kirigami.Units.longDuration
            highlightResizeDuration: Kirigami.Units.longDuration
            highlightFollowsCurrentItem: true

            highlight: Item {
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Kirigami.Units.largeSpacing
                    y: 0
                    height: 3
                    radius: 1.5
                    color: menu.accent
                    opacity: menu.searching ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                }
            }

            delegate: MouseArea {
                id: tabItem
                required property int index
                required property var modelData
                readonly property bool current: !menu.searching && menu.currentTab === index

                width: tabLabel.implicitWidth + Kirigami.Units.gridUnit * 2
                height: ListView.view.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    searchField.text = "";
                    menu.currentTab = index;
                    searchField.forceActiveFocus();
                }

                PC3.Label {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: tabItem.modelData.label
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    font.weight: tabItem.current ? Font.DemiBold : Font.Normal
                    opacity: tabItem.current || tabItem.containsMouse ? 1 : 0.7
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: menu.pad
            Layout.rightMargin: menu.pad
            currentIndex: menu.searching ? 4 : ["pinned", "recent", "all", "category"].indexOf(menu.tab.kind)

            TileView {
                id: pinnedView
                menuView: menu
                sourceModel: root.rootModel.favoritesModel
                reorderable: true
                placeholder: i18n("Nothing pinned yet")
                placeholderExplanation: i18n("Right-click any app and choose “Add to Favorites”. Drag pinned apps to reorder them.")
            }
            AppList {
                id: recentView
                menuView: menu
                model: Plasmoid.configuration.showRecent ? root.recentModel : null
                placeholder: i18n("No recent apps or files")
            }
            TileView {
                id: appsView
                menuView: menu
                sourceModel: root.allAppsModel
                sectioned: true
                placeholder: i18n("Loading applications…")
            }
            TileView {
                id: categoryView
                menuView: menu
                sourceModel: {
                    root.rootRevision;
                    return menu.tab.kind === "category" ? root.rootModel.modelForRow(menu.tab.row) : null;
                }
                placeholder: i18n("This category is empty")
            }
            AppList {
                id: resultsView
                menuView: menu
                defaultFirst: true
                model: root.runnerModel.count > 0 ? root.runnerModel.modelForRow(0) : null
                placeholder: root.runnerModel.querying ? "" : i18n("No results for “%1”", root.searchText)
                onCountChanged: {
                    keyboardNav = true;
                    currentIndex = count > 0 ? 0 : -1;
                }
            }
        }

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.margins: menu.pad
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
            radius: Kirigami.Units.cornerRadius * 1.5
            color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
            border.width: 1
            border.color: searchField.activeFocus ? Qt.alpha(menu.accent, 0.5) : menu.hairline

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: parent.radius / 2
                anchors.rightMargin: parent.radius / 2
                height: 3
                radius: 1.5
                color: menu.accent
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                PC3.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    focus: true
                    background: null
                    placeholderText: i18n("Search")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    onTextChanged: root.searchText = text

                    Keys.onPressed: (event) => {
                        const v = menu.activeView;
                        switch (event.key) {
                        case Qt.Key_Up:
                        case Qt.Key_Down:
                            v.moveKey(event.key);
                            event.accepted = true;
                            break;
                        case Qt.Key_Left:
                        case Qt.Key_Right:
                            if ((event.modifiers & Qt.ControlModifier) && v.reorderable) {
                                v.moveCurrentBy(event.key === Qt.Key_Right ? 1 : -1);
                                event.accepted = true;
                            } else if (text === "" && v.isGrid) {
                                v.moveKey(event.key);
                                event.accepted = true;
                            }
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            v.activate();
                            event.accepted = true;
                            break;
                        case Qt.Key_Escape:
                            if (text !== "") {
                                text = "";
                            } else {
                                root.expanded = false;
                            }
                            event.accepted = true;
                            break;
                        case Qt.Key_Tab:
                        case Qt.Key_Backtab:
                            if (!menu.searching) {
                                const n = menu.tabs.length;
                                menu.currentTab = (menu.currentTab + (event.key === Qt.Key_Tab ? 1 : n - 1)) % n;
                            }
                            event.accepted = true;
                            break;
                        case Qt.Key_Menu:
                            v.openCurrentContextMenu();
                            event.accepted = true;
                            break;
                        }
                    }
                }

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    source: "search-symbolic"
                    opacity: 0.7
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing * 2
                    Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    color: menu.hairline
                }

                PC3.ToolButton {
                    id: filterButton
                    text: root.filterNames[root.searchFilter]
                    flat: true
                    onClicked: filterMenu.openRelative()

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        PC3.Label {
                            text: filterButton.text
                        }
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: "arrow-down-symbolic"
                        }
                    }
                }
            }
        }
    }

    PlasmaExtras.Menu {
        id: filterMenu
        visualParent: filterButton

        PlasmaExtras.MenuItem { text: root.filterNames[0]; checkable: true; checked: root.searchFilter === 0; onClicked: root.searchFilter = 0 }
        PlasmaExtras.MenuItem { text: root.filterNames[1]; checkable: true; checked: root.searchFilter === 1; onClicked: root.searchFilter = 1 }
        PlasmaExtras.MenuItem { text: root.filterNames[2]; checkable: true; checked: root.searchFilter === 2; onClicked: root.searchFilter = 2 }
        PlasmaExtras.MenuItem { text: root.filterNames[3]; checkable: true; checked: root.searchFilter === 3; onClicked: root.searchFilter = 3 }
    }

    PlasmaExtras.Menu {
        id: powerMenu
        visualParent: powerButton

        PlasmaExtras.MenuItem { text: i18n("Lock"); icon: "system-lock-screen"; visible: session.canLock; onClicked: { root.expanded = false; session.lock(); } }
        PlasmaExtras.MenuItem { text: i18n("Sleep"); icon: "system-suspend"; visible: session.canSuspend; onClicked: { root.expanded = false; session.suspend(); } }
        PlasmaExtras.MenuItem { text: i18n("Hibernate"); icon: "system-suspend-hibernate"; visible: session.canHibernate; onClicked: { root.expanded = false; session.hibernate(); } }
        PlasmaExtras.MenuItem { text: i18n("Restart"); icon: "system-reboot"; visible: session.canReboot; onClicked: { root.expanded = false; session.requestReboot(); } }
        PlasmaExtras.MenuItem { text: i18n("Shut Down"); icon: "system-shutdown"; visible: session.canShutdown; onClicked: { root.expanded = false; session.requestShutdown(); } }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: i18n("Switch User"); icon: "system-switch-user"; visible: session.canSwitchUser; onClicked: { root.expanded = false; session.switchUser(); } }
        PlasmaExtras.MenuItem { text: i18n("Log Out"); icon: "system-log-out"; visible: session.canLogout; onClicked: { root.expanded = false; session.requestLogout(); } }
    }
}
