.pragma library

function runVersionedMigrations(rawJson, isFreshInstall, logger) {
  if (!rawJson || isFreshInstall) {
    logger.i("Settings", "Fresh install detected, skipping migrations");
    return;
  }

  logger.i("Settings", "No migrations needed for quicknix");
}

function upgradeWidget(widget, widgetMetadata) {
  var widgetBefore = JSON.stringify(widget);
  var keys = Object.keys(widgetMetadata[widget.id]);

  for (var j = 0; j < Object.keys(widget).length; j++) {
    var key = Object.keys(widget)[j];
    if (key === "id") {
      continue;
    }
    if (!keys.includes(key)) {
      delete widget[key];
    }
  }

  for (var i = 0; i < keys.length; i++) {
    var metadataKey = keys[i];
    if (metadataKey === "id") {
      continue;
    }

    if (widget[metadataKey] === undefined) {
      widget[metadataKey] = widgetMetadata[widget.id][metadataKey];
    }
  }

  return JSON.stringify(widget) !== widgetBefore;
}

function upgradeBarWidgets(adapter, widgetRegistry, logger) {
  var sections = ["left", "center", "right"];
  var removedWidget = false;

  for (var s = 0; s < sections.length; s++) {
    var sectionName = sections[s];
    var widgets = adapter.bar.widgets[sectionName];
    for (var i = widgets.length - 1; i >= 0; i--) {
      var widget = widgets[i];
      if (!widgetRegistry.hasWidget(widget.id)) {
        logger.w("Settings", "!!! Deleted invalid bar widget " + widget.id + " !!!");
        widgets.splice(i, 1);
        removedWidget = true;
      }
    }
  }

  for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
    var upgradeSectionName = sections[sectionIndex];
    for (var widgetIndex = 0; widgetIndex < adapter.bar.widgets[upgradeSectionName].length; widgetIndex++) {
      var currentWidget = adapter.bar.widgets[upgradeSectionName][widgetIndex];

      if (widgetRegistry.widgetMetadata[currentWidget.id] === undefined) {
        continue;
      }

      if (upgradeWidget(currentWidget, widgetRegistry.widgetMetadata)) {
        logger.d("Settings", "Upgraded " + currentWidget.id + " widget: " + JSON.stringify(currentWidget));
      }
    }
  }

  return removedWidget;
}
