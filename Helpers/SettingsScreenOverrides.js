.pragma library

function findOverride(overrides, screenName) {
  if (!screenName || !overrides || overrides.length === undefined) {
    return null;
  }

  for (var i = 0; i < overrides.length; i++) {
    if (overrides[i] && overrides[i].name === screenName) {
      return overrides[i];
    }
  }

  return null;
}

function findOverrideIndex(overrides, screenName) {
  if (!screenName || !overrides || overrides.length === undefined) {
    return -1;
  }

  for (var i = 0; i < overrides.length; i++) {
    if (overrides[i] && overrides[i].name === screenName) {
      return i;
    }
  }

  return -1;
}

function isEnabled(overrides, screenName) {
  var override = findOverride(overrides, screenName);
  if (!override) {
    return false;
  }

  return override.enabled !== false;
}

function getEffectiveValue(overrides, screenName, property, fallbackValue) {
  var override = findOverride(overrides, screenName);
  if (override && override.enabled !== false && override[property] !== undefined) {
    return override[property];
  }

  return fallbackValue;
}

function hasOverride(overrides, screenName, property) {
  var override = findOverride(overrides, screenName);
  if (!override) {
    return false;
  }

  if (property) {
    return override[property] !== undefined;
  }

  var keys = Object.keys(override);
  return keys.length > 1 || (keys.length === 1 && keys[0] !== "name");
}

function setOverride(overrides, screenName, property, value) {
  if (!screenName) {
    return overrides;
  }

  var nextOverrides = JSON.parse(JSON.stringify(overrides || []));
  if (nextOverrides.length === undefined) {
    nextOverrides = [];
  }

  var index = findOverrideIndex(nextOverrides, screenName);
  if (index === -1) {
    var newEntry = {
      "name": screenName
    };
    newEntry[property] = value;
    nextOverrides.push(newEntry);
  } else {
    nextOverrides[index][property] = value;
  }

  return nextOverrides;
}

function clearOverride(overrides, screenName, property) {
  if (!screenName || !overrides || overrides.length === undefined) {
    return overrides;
  }

  var nextOverrides = JSON.parse(JSON.stringify(overrides));
  var index = findOverrideIndex(nextOverrides, screenName);
  if (index === -1) {
    return nextOverrides;
  }

  if (property) {
    delete nextOverrides[index][property];
    var keys = Object.keys(nextOverrides[index]);
    if (keys.length <= 1 && (keys.length === 0 || keys[0] === "name")) {
      nextOverrides.splice(index, 1);
    }
  } else {
    nextOverrides.splice(index, 1);
  }

  return nextOverrides;
}
