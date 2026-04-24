import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Rectangle {
  id: root
  Layout.fillWidth: true
  Layout.minimumHeight: (60 * Style.uiScaleRatio) + Style.margin2M
  Layout.preferredHeight: (60 * Style.uiScaleRatio) + Style.margin2M
  implicitHeight: (60 * Style.uiScaleRatio) + Style.margin2M
  radius: Style.radiusL
  color: Color.mPrimary

  readonly property var now: Time.now
  readonly property int currentMonth: now.getMonth()
  readonly property int currentYear: now.getFullYear()

  ColumnLayout {
    id: capsuleColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.topMargin: Style.marginM
    anchors.bottomMargin: Style.marginM
    anchors.rightMargin: clockLoader.width + Style.margin2XL
    anchors.leftMargin: Style.marginXL
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      height: 60 * Style.uiScaleRatio
      clip: true
      spacing: Style.marginS

      NText {
        Layout.preferredWidth: implicitWidth
        elide: Text.ElideNone
        clip: true
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        text: root.now.getDate()
        pointSize: Style.fontSizeXXXL * 1.5
        font.weight: Style.fontWeightBold
        color: Color.mOnPrimary
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        Layout.bottomMargin: Style.marginXXS
        Layout.topMargin: -Style.marginXXS
        spacing: -Style.marginXS

        RowLayout {
          spacing: Style.marginS

          NText {
            text: I18n.locale.monthName(root.currentMonth, Locale.LongFormat).toUpperCase()
            pointSize: Style.fontSizeXL * 1.1
            font.weight: Style.fontWeightBold
            color: Color.mOnPrimary
            Layout.alignment: Qt.AlignBaseline
            elide: Text.ElideRight
          }

          NText {
            text: root.currentYear.toString()
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Qt.alpha(Color.mOnPrimary, 0.7)
            Layout.alignment: Qt.AlignBaseline
          }
        }

        NText {
          text: I18n.locale.dayName(root.now.getDay(), Locale.LongFormat)
          pointSize: Style.fontSizeM
          color: Color.mOnPrimary
        }
      }

      Item {
        Layout.fillWidth: true
      }
    }
  }

  NClock {
    id: clockLoader
    anchors.right: parent.right
    anchors.rightMargin: Style.marginXL
    anchors.verticalCenter: parent.verticalCenter
    clockStyle: "digital"
    progressColor: Color.mOnPrimary
    Layout.alignment: Qt.AlignVCenter
    now: root.now
  }
}
