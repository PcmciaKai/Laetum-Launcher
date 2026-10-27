import QtQuick
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

PC3.ToolButton {
    id: button

    property string iconName
    property string tooltip

    icon.name: iconName
    icon.width: Kirigami.Units.iconSizes.smallMedium
    icon.height: Kirigami.Units.iconSizes.smallMedium
    display: PC3.AbstractButton.IconOnly
    text: tooltip
    flat: true

    PC3.ToolTip.text: tooltip
    PC3.ToolTip.visible: hovered
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
}
