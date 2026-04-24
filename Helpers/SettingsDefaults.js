.pragma library

function getDefaultValue(defaultSettings, path) {
  if (!defaultSettings) {
    return undefined;
  }

  var parts = path.split(".");
  var current = defaultSettings;

  for (var i = 0; i < parts.length; i++) {
    if (current === undefined || current === null) {
      return undefined;
    }
    current = current[parts[i]];
  }

  return current;
}

function isValueChanged(defaultSettings, path, currentValue) {
  var defaultValue = getDefaultValue(defaultSettings, path);
  if (defaultValue === undefined) {
    return false;
  }

  if (typeof currentValue === "object" && typeof defaultValue === "object") {
    return JSON.stringify(currentValue) !== JSON.stringify(defaultValue);
  }

  return currentValue !== defaultValue;
}

function formatDefaultValueForTooltip(defaultSettings, path) {
  var defaultValue = getDefaultValue(defaultSettings, path);
  if (defaultValue === undefined) {
    return "";
  }

  if (typeof defaultValue === "boolean") {
    return defaultValue ? "true" : "false";
  } else if (typeof defaultValue === "number") {
    return defaultValue.toString();
  } else if (typeof defaultValue === "string") {
    return defaultValue === "" ? "(empty)" : defaultValue;
  } else if (Array.isArray(defaultValue)) {
    return defaultValue.length === 0 ? "(empty)" : "[" + defaultValue.length + " items]";
  } else if (typeof defaultValue === "object") {
    return "(object)";
  }

  return String(defaultValue);
}
