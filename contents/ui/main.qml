import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: root

    Plasmoid.icon: Plasmoid.configuration.icon
    preferredRepresentation: compactRepresentation
    hideOnWindowDeactivate: true
    toolTipMainText: Plasmoid.title

    // Search state shared with the popup
    property string searchText: ""
    property int searchFilter: 0
    readonly property var filterNames: [i18n("Everything"), i18n("Apps"), i18n("Files"), i18n("Settings")]
    readonly property var filterRunners: [
        [],
        ["krunner_services"],
        ["baloosearch", "locations", "krunner_placesrunner", "krunner_recentdocuments"],
        ["krunner_systemsettings"]
    ]

    // Plasma styles (e.g. Nobara) ship their own highlight colour, so read the
    // colour scheme's accent from kdeglobals instead of trusting the Plasma theme.
    property color accentColor: Kirigami.Theme.highlightColor
    readonly property string accentCommand: "sh -c 'a=$(kreadconfig6 --group General --key AccentColor); "
        + "[ -n \"$a\" ] || a=$(kreadconfig6 --group Colors:Selection --key BackgroundNormal); echo \"$a\"'"

    function refreshAccent() {
        if (Plasmoid.configuration.useSystemAccent) {
            accentReader.connectSource(accentCommand);
        } else {
            accentColor = Qt.binding(() => Kirigami.Theme.highlightColor);
        }
    }

    P5Support.DataSource {
        id: accentReader
        engine: "executable"
        onNewData: (source, data) => {
            const parts = (data.stdout || "").trim().split(",").map(Number);
            if (parts.length >= 3 && parts.every(n => !isNaN(n))) {
                root.accentColor = Qt.rgba(parts[0] / 255, parts[1] / 255, parts[2] / 255, 1);
            }
            disconnectSource(source);
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onUseSystemAccentChanged() {
            root.refreshAccent();
        }
    }

    // Same backend models Kickoff uses: favourites are shared with Kickoff/Kicker
    readonly property Kicker.RootModel rootModel: Kicker.RootModel {
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false

        Component.onCompleted: favoritesModel.initForClient("local.laetum.favorites.instance-" + Plasmoid.id)
    }

    // Bumped whenever RootModel rebuilds, so group bindings re-evaluate
    property int rootRevision: 0

    Connections {
        target: root.rootModel
        function onModelReset() {
            root.rootRevision++;
        }
        function onCountChanged() {
            root.rootRevision++;
        }
    }

    // [{label, row, count}] for every group RootModel exposes
    readonly property var appGroups: {
        rootRevision;
        const groups = [];
        for (let i = 0; i < rootModel.count; ++i) {
            const m = rootModel.modelForRow(i);
            groups.push({ label: rootModel.labelForRow(i), row: i, count: m ? m.count : 0 });
        }
        return groups;
    }

    // "All Applications" is the largest group; the rest are categories
    readonly property int allAppsRow: appGroups.reduce((best, g) => (best < 0 || g.count > appGroups[best].count) ? g.row : best, -1)
    readonly property var allAppsModel: {
        rootRevision;
        return allAppsRow >= 0 ? rootModel.modelForRow(allAppsRow) : null;
    }
    readonly property var categories: appGroups.filter(g => g.row !== allAppsRow && g.count > 0)

    // Publish category names so the settings page can offer them
    onCategoriesChanged: {
        const names = categories.map(c => c.label);
        if (names.join("\n") !== Plasmoid.configuration.availableCategories.join("\n")) {
            Plasmoid.configuration.availableCategories = names;
        }
    }

    readonly property Kicker.RecentUsageModel recentModel: Kicker.RecentUsageModel {
        favoritesModel: root.rootModel.favoritesModel
    }

    readonly property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        appletInterface: root
        mergeResults: true
        favoritesModel: root.rootModel.favoritesModel
        runners: root.filterRunners[root.searchFilter]
        query: root.searchText
    }

    // Re-run the query when the filter changes so results match the new runner set
    onSearchFilterChanged: {
        runnerModel.query = "";
        Qt.callLater(() => { runnerModel.query = Qt.binding(() => root.searchText); });
    }

    onExpandedChanged: {
        if (root.expanded) {
            refreshAccent();
        }
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Applications…")
            icon.name: "kmenuedit"
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    compactRepresentation: MouseArea {
        id: compact

        property bool wasExpanded: false
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        Layout.minimumWidth: vertical ? -1 : height
        Layout.maximumWidth: vertical ? -1 : height
        Layout.minimumHeight: vertical ? width : -1
        Layout.maximumHeight: vertical ? width : -1

        hoverEnabled: true
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compact.containsMouse
        }
    }

    fullRepresentation: MenuView {}

    Component.onCompleted: {
        rootModel.refresh();
        refreshAccent();
    }
}
