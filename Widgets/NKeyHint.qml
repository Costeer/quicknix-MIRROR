import QtQuick
import qs.Commons

Item {
  id: root

  property string key: ""
  property bool active: false

  readonly property real badgeSize: Math.round(Style.baseWidgetSize * 0.55)

  width: badgeSize
  height: badgeSize

  Rectangle {
    id: keyBg
    anchors.fill: parent
    radius: Style.iRadiusS
    color: Color.mSurfaceVariant
    border.color: Color.mOutline
    border.width: Style.borderS
    scale: 1.0

    Behavior on scale {
      enabled: !Color.isTransitioning
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutBack
      }
    }

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
      }
    }

    Text {
      id: keyText
      anchors.centerIn: parent
      text: root.key
      font.family: Settings.data.ui.fontFixed || "monospace"
      font.pixelSize: Math.round(Style.fontSizeXS * Style.uiScaleRatio)
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        enabled: !Color.isTransitioning
        ColorAnimation {
          duration: Style.animationFast
        }
      }
    }
  }

  onActiveChanged: {
    if (active) {
      activateAnimation.start();
      resetTimer.start();
    }
  }

  SequentialAnimation {
    id: activateAnimation
    NumberAnimation {
      target: keyBg
      property: "scale"
      to: 1.15
      duration: Style.animationFaster
    }
    PropertyAction {
      target: keyBg
      property: "color"
      value: Color.mPrimary
    }
    PropertyAction {
      target: keyText
      property: "color"
      value: Color.mOnPrimary
    }
    PauseAnimation {
      duration: 100
    }
    NumberAnimation {
      target: keyBg
      property: "scale"
      to: 1.0
      duration: Style.animationNormal
      easing.type: Easing.OutBack
    }
    PropertyAction {
      target: keyBg
      property: "color"
      value: Color.mSurfaceVariant
    }
    PropertyAction {
      target: keyText
      property: "color"
      value: Color.mOnSurface
    }
  }

  Timer {
    id: resetTimer
    interval: 400
    onTriggered: root.active = false
  }
}
