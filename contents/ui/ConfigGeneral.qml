import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    property string cfg_icon
    property alias cfg_columns: columnsSpin.value
    property alias cfg_defaultTab: tabCombo.currentIndex
    property alias cfg_storeApp: storeField.text
    property alias cfg_terminalApp: terminalField.text
    property alias cfg_showRecent: recentCheck.checked
    property alias cfg_showStoreButton: storeCheck.checked
    property alias cfg_showFilesButton: filesCheck.checked
    property alias cfg_showTerminalButton: terminalCheck.checked
    property alias cfg_showSettingsButton: settingsCheck.checked
    property alias cfg_showInfoCenterButton: infoCheck.checked
    property alias cfg_headerIconSize: iconSizeCombo.currentIndex
    property alias cfg_animateHover: hoverCheck.checked
    property alias cfg_animateClick: clickCheck.checked
    property var cfg_categoryTabs: []
    property var cfg_availableCategories: []

    // Defaults Plasma passes in alongside the values
    property string cfg_iconDefault
    property int cfg_columnsDefault
    property int cfg_defaultTabDefault
    property string cfg_storeAppDefault
    property string cfg_terminalAppDefault
    property bool cfg_showRecentDefault
    property bool cfg_showStoreButtonDefault
    property bool cfg_showFilesButtonDefault
    property bool cfg_showTerminalButtonDefault
    property bool cfg_showSettingsButtonDefault
    property bool cfg_showInfoCenterButtonDefault
    property int cfg_headerIconSizeDefault
    property bool cfg_animateHoverDefault
    property bool cfg_animateClickDefault
    property var cfg_categoryTabsDefault
    property var cfg_availableCategoriesDefault

    Kirigami.FormLayout {
        QQC2.Button {
            Kirigami.FormData.label: i18n("Panel icon:")
            icon.name: cfg_icon
            icon.width: Kirigami.Units.iconSizes.large
            icon.height: Kirigami.Units.iconSizes.large
            onClicked: iconDialog.open()

            KIconThemes.IconDialog {
                id: iconDialog
                onIconNameChanged: cfg_icon = iconName || "start-here-kde-symbolic"
            }
        }

        QQC2.SpinBox {
            id: columnsSpin
            Kirigami.FormData.label: i18n("Grid columns:")
            from: 3
            to: 8
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Header")
        }

        QQC2.ComboBox {
            id: iconSizeCombo
            Kirigami.FormData.label: i18n("Button size:")
            model: [i18n("Small"), i18n("Medium"), i18n("Large")]
        }

        QQC2.CheckBox {
            id: storeCheck
            Kirigami.FormData.label: i18n("Buttons:")
            text: i18n("Software store")
        }
        QQC2.TextField {
            id: storeField
            enabled: storeCheck.checked
            Layout.leftMargin: Kirigami.Units.gridUnit
            placeholderText: i18n("Desktop file ID or command")
        }

        QQC2.CheckBox {
            id: filesCheck
            text: i18n("Files")
        }

        QQC2.CheckBox {
            id: terminalCheck
            text: i18n("Terminal")
        }
        QQC2.TextField {
            id: terminalField
            enabled: terminalCheck.checked
            Layout.leftMargin: Kirigami.Units.gridUnit
            placeholderText: i18n("Desktop file ID or command")
        }

        QQC2.CheckBox {
            id: settingsCheck
            text: i18n("System Settings")
        }

        QQC2.CheckBox {
            id: infoCheck
            text: i18n("Info Center")
        }

        QQC2.Label {
            text: i18n("The power button is always shown.")
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Items")
        }

        QQC2.CheckBox {
            id: hoverCheck
            Kirigami.FormData.label: i18n("Animations:")
            text: i18n("Animate on hover")
        }

        QQC2.CheckBox {
            id: clickCheck
            text: i18n("Animate on click")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Tabs")
        }

        QQC2.CheckBox {
            id: recentCheck
            Kirigami.FormData.label: i18n("Recent:")
            text: i18n("Show the Recent tab")
        }

        QQC2.ComboBox {
            id: tabCombo
            Kirigami.FormData.label: i18n("Open on tab:")
            model: [i18n("Pinned"), i18n("Recent"), i18n("All Apps")]
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Category tabs:")
            visible: cfg_availableCategories.length === 0
            text: i18n("Open the menu once so it can list your categories.")
            opacity: 0.7
        }

        Repeater {
            model: cfg_availableCategories

            QQC2.CheckBox {
                required property int index
                required property string modelData
                Kirigami.FormData.label: index === 0 ? i18n("Category tabs:") : ""
                text: modelData
                checked: cfg_categoryTabs.includes(modelData)
                onToggled: {
                    const set = cfg_categoryTabs.filter(c => c !== modelData);
                    if (checked) {
                        set.push(modelData);
                    }
                    cfg_categoryTabs = set;
                }
            }
        }
    }
}
