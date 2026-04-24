import QtQuick
import qs.Commons

Item {
  id: root

  property real value: 0.0
  property real thickness: 16
  property real cornerRadius: thickness / 2
  property color trackColor: Color.mSurfaceVariant
  property color fillColor: Color.mPrimary
  property color dividerColor: Color.mPrimary
  property color endDotColor: "white"
  property real dividerWidth: 2
  readonly property real gapOnEachSide: dividerWidth * 3.1
  readonly property real totalGap: gapOnEachSide * 2 + dividerWidth
  property real endDotSize: 5
  property real innerCornerRadius: Math.max(1, Math.min(cornerRadius, thickness * 0.25))
  property bool enabled: true
  property bool pressed: false
  property bool hovering: false

  implicitWidth: 260
  implicitHeight: thickness

  function setValue(v) {
    var c = Math.max(0, Math.min(1, v))
    value = c
  }

  readonly property real _clamped: Math.max(0, Math.min(1, value))
  readonly property real _centerX: _clamped * root.width
  readonly property real _dw: dividerWidth / 2
  readonly property real _halfSpanBase: _dw + gapOnEachSide
  readonly property real _availLeft: _centerX
  readonly property real _availRight: root.width - _centerX
  readonly property real _s: Math.min(1, Math.max(0, _availLeft / Math.max(1, _halfSpanBase)), Math.max(0, _availRight / Math.max(1, _halfSpanBase)))
  readonly property real _leftEdge: Math.max(0, _centerX - _s * _halfSpanBase)
  readonly property real _rightEdge: Math.min(root.width, _centerX + _s * _halfSpanBase)

  Item {
    id: leftGroup
    x: 0
    anchors.verticalCenter: parent.verticalCenter
    width: root._leftEdge
    height: root.thickness

    Rectangle {
      x: root.cornerRadius
      width: Math.max(0, parent.width - root.cornerRadius)
      height: root.thickness
      radius: root.innerCornerRadius
      color: root.fillColor
      antialiasing: true
      visible: width > 0
    }

    Rectangle {
      width: Math.min(root.thickness, parent.width)
      height: root.thickness
      radius: root.cornerRadius
      color: root.fillColor
      antialiasing: true
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Behavior on width {
      NumberAnimation {
        duration: 140
        easing.type: Easing.InOutQuad
      }
    }
  }

  Item {
    id: rightGroup
    x: root._rightEdge
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, root.width - root._rightEdge)
    height: root.thickness

    Rectangle {
      x: 0
      width: Math.max(0, parent.width - root.cornerRadius)
      height: root.thickness
      radius: root.innerCornerRadius
      color: root.trackColor
      antialiasing: true
      visible: width > 0
    }

    Rectangle {
      width: Math.min(root.thickness, parent.width)
      height: root.thickness
      radius: root.cornerRadius
      color: root.trackColor
      antialiasing: true
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }

    Behavior on x {
      NumberAnimation {
        duration: 140
        easing.type: Easing.InOutQuad
      }
    }
    Behavior on width {
      NumberAnimation {
        duration: 140
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: dividerLine
    width: root.dividerWidth
    height: root.thickness * 2.5
    radius: width / 2
    color: root.dividerColor
    anchors.verticalCenter: parent.verticalCenter
    x: root._centerX - width / 2
    z: 10

    Behavior on x {
      NumberAnimation {
        duration: 140
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: rightDot
    width: root.endDotSize
    height: root.endDotSize
    radius: width / 2
    color: root.endDotColor
    anchors.verticalCenter: parent.verticalCenter
    x: Math.round(root.width - root.endDotSize - Math.max(2, root.endDotSize / 2))
    visible: root._rightEdge < root.width - 0.0001
    opacity: 0.9
    z: 11
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onPressed: function (e) {
      root.pressed = true
      var rel = e.x / Math.max(1, root.width)
      root.setValue(rel)
    }
    onPositionChanged: function (e) {
      if (!pressed)
        return
      var rel = e.x / Math.max(1, root.width)
      root.setValue(rel)
    }
    onReleased: root.pressed = false
    onCanceled: root.pressed = false
  }
}
