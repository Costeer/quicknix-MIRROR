import QtQuick
import qs.Commons
import qs.Services.UI

Item {
  id: root

  readonly property bool sliderActive: activeFocus || splitSlider.pressed
  property color fillColor: Color.mPrimary
  property var cutoutColor: Color.mSurface
  property bool snapAlways: true
  property real heightRatio: 0.7
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool hovering: false
  property bool pressed: splitSlider.pressed

  property real from: 0
  property real to: 1
  property real value: 0
  property real stepSize: 0.01

  readonly property color effectiveFillColor: enabled ? fillColor : Color.mOutline

  signal moved(real value)
  signal sliderPressedChanged(bool isPressed)

  implicitWidth: splitSlider.implicitWidth
  implicitHeight: splitSlider.thickness * 2.5

  function _norm(v) {
    var range = to - from
    if (range === 0)
      return 0
    return (v - from) / range
  }

  function _denorm(n) {
    return from + n * (to - from)
  }

  function _snap(v) {
    if (!snapAlways || stepSize <= 0)
      return v
    var steps = Math.round((v - from) / stepSize)
    return from + steps * stepSize
  }

  SplitLinearSlider {
    id: splitSlider
    anchors.fill: parent
    value: root._norm(root.value)
    fillColor: root.effectiveFillColor
    trackColor: Color.mSurfaceVariant
    dividerColor: root.effectiveFillColor
    endDotColor: "white"
    enabled: root.enabled
    hovering: root.hovering

    onValueChanged: {
      if (splitSlider.pressed) {
        var snapped = root._snap(root._denorm(splitSlider.value))
        if (snapped !== root.value) {
          root.value = snapped
          root.moved(snapped)
        }
      }
    }

    onPressedChanged: {
      root.sliderPressedChanged(splitSlider.pressed)
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    propagateComposedEvents: true
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      root.hovering = true
      if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        TooltipService.show(root, root.tooltipText, root.tooltipDirection)
      }
    }

    onExited: {
      root.hovering = false
      if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        TooltipService.hide()
      }
    }

    onWheel: function (wheel) {
      if (!root.enabled)
        return
      var delta = wheel.angleDelta.y || wheel.angleDelta.x
      var increment = delta > 0 ? root.stepSize : -root.stepSize
      var newVal = Math.max(root.from, Math.min(root.to, root.value + increment))
      if (newVal !== root.value) {
        root.value = newVal
        root.moved(newVal)
      }
    }
  }

  Connections {
    target: splitSlider
    function onPressedChanged() {
      if (splitSlider.pressed) {
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide()
        }
      }
    }
  }
}
