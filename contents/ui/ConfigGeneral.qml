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
    property alias cfg_showRecent: recentCheck.checked
    property alias cfg_useSystemAccent: accentCheck.checked
    property var cfg_categoryTabs: []
    property var cfg_availableCategories: []

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

        QQC2.CheckBox {
            id: accentCheck
            Kirigami.FormData.label: i18n("Accent colour:")
            text: i18n("Use the KDE colour scheme's accent")
        }

        QQC2.TextField {
            id: storeField
            Kirigami.FormData.label: i18n("Store app (desktop file id):")
            placeholderText: i18n("Leave empty to hide the store button")
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
