pragma Singleton

import QtQuick
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property bool _initialized: false
  property bool _restartPending: false

  readonly property bool enabled: Settings.data.nightLight.enabled
  readonly property bool forced: Settings.data.nightLight.forced
  readonly property bool autoSchedule: Settings.data.nightLight.autoSchedule
  readonly property string nightTemp: Settings.data.nightLight.nightTemp
  readonly property string dayTemp: Settings.data.nightLight.dayTemp
  readonly property string manualSunrise: Settings.data.nightLight.manualSunrise
  readonly property string manualSunset: Settings.data.nightLight.manualSunset
  readonly property string latitude: Settings.data.nightLight.latitude || ""
  readonly property string longitude: Settings.data.nightLight.longitude || ""
  readonly property real gamma: Settings.data.nightLight.gamma || 1.0

  onEnabledChanged: scheduleRestart()
  onForcedChanged: scheduleRestart()
  onAutoScheduleChanged: scheduleRestart()
  onNightTempChanged: scheduleRestart()
  onDayTempChanged: scheduleRestart()
  onManualSunriseChanged: scheduleRestart()
  onManualSunsetChanged: scheduleRestart()
  onLatitudeChanged: scheduleRestart()
  onLongitudeChanged: scheduleRestart()
  onGammaChanged: scheduleRestart()

  function init() {
    if (_initialized)
      return;

    _initialized = true;
    scheduleRestart();
  }

  function scheduleRestart() {
    if (!_initialized || _restartPending)
      return;

    _restartPending = true;
    Qt.callLater(restart);
  }

  function restart() {
    _restartPending = false;
    nightLightProcess.running = false;

    if (enabled) {
      nightLightProcess.command = buildCommand();
      Logger.i("NightLightService", "Starting quicknix-nightlight");
      nightLightProcess.running = true;
    }
  }

  function buildCommand(): list<string> {
    var args = ["quicknix-nightlight", "--temperature", String(effectiveTemperature()), "--gamma", String(gamma)];

    return args;
  }

  function effectiveTemperature(): string {
    if (forced) {
      return nightTemp;
    }

    return isNightActive() ? nightTemp : dayTemp;
  }

  function isNightActive(): bool {
    if (autoSchedule) {
      const solarSchedule = calculateSolarSchedule();
      if (solarSchedule.valid) {
        const now = new Date();
        const currentMinutes = now.getHours() * 60 + now.getMinutes();
        return currentMinutes < solarSchedule.sunrise || currentMinutes >= solarSchedule.sunset;
      }
    }

    const now = new Date();
    const sunriseMinutes = parseTimeMinutes(manualSunrise);
    const sunsetMinutes = parseTimeMinutes(manualSunset);
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    if (sunriseMinutes <= sunsetMinutes) {
      return currentMinutes < sunriseMinutes || currentMinutes >= sunsetMinutes;
    }
    return currentMinutes >= sunsetMinutes && currentMinutes < sunriseMinutes;
  }

  function calculateSolarSchedule(): var {
    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);
    if (!isFinite(lat) || !isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
      return {
        "valid": false
      };
    }

    const now = new Date();
    const day = dayOfYear(now);
    const sunrise = calculateSolarEventMinutes(day, lat, lon, true);
    const sunset = calculateSolarEventMinutes(day, lat, lon, false);
    if (sunrise < 0 || sunset < 0) {
      return {
        "valid": false
      };
    }

    return {
      "valid": true,
      "sunrise": sunrise,
      "sunset": sunset
    };
  }

  function dayOfYear(date: var): int {
    const start = new Date(date.getFullYear(), 0, 0);
    return Math.floor((date - start) / 86400000);
  }

  function calculateSolarEventMinutes(day: int, lat: real, lon: real, sunrise: bool): int {
    const lngHour = lon / 15;
    const t = sunrise ? day + ((6 - lngHour) / 24) : day + ((18 - lngHour) / 24);
    const meanAnomaly = (0.9856 * t) - 3.289;
    var trueLongitude = meanAnomaly + (1.916 * Math.sin(degToRad(meanAnomaly))) + (0.020 * Math.sin(degToRad(2 * meanAnomaly))) + 282.634;
    trueLongitude = normalizeDegrees(trueLongitude);

    var rightAscension = radToDeg(Math.atan(0.91764 * Math.tan(degToRad(trueLongitude))));
    rightAscension = normalizeDegrees(rightAscension);
    rightAscension += Math.floor(trueLongitude / 90) * 90 - Math.floor(rightAscension / 90) * 90;
    rightAscension /= 15;

    const sinDeclination = 0.39782 * Math.sin(degToRad(trueLongitude));
    const cosDeclination = Math.cos(Math.asin(sinDeclination));
    const cosHour = (Math.cos(degToRad(90.833)) - (sinDeclination * Math.sin(degToRad(lat)))) / (cosDeclination * Math.cos(degToRad(lat)));
    if (cosHour > 1 || cosHour < -1) {
      return -1;
    }

    var hour = sunrise ? 360 - radToDeg(Math.acos(cosHour)) : radToDeg(Math.acos(cosHour));
    hour /= 15;

    const localMeanTime = hour + rightAscension - (0.06571 * t) - 6.622;
    const utcTime = normalizeHours(localMeanTime - lngHour);
    const timezoneOffsetHours = -new Date().getTimezoneOffset() / 60;
    const localTime = normalizeHours(utcTime + timezoneOffsetHours);
    return Math.round(localTime * 60);
  }

  function degToRad(value: real): real {
    return value * Math.PI / 180;
  }

  function radToDeg(value: real): real {
    return value * 180 / Math.PI;
  }

  function normalizeDegrees(value: real): real {
    var result = value % 360;
    return result < 0 ? result + 360 : result;
  }

  function normalizeHours(value: real): real {
    var result = value % 24;
    return result < 0 ? result + 24 : result;
  }

  function parseTimeMinutes(value: string): int {
    const parts = String(value || "").split(":");
    if (parts.length !== 2)
      return 0;
    const hours = Math.max(0, Math.min(23, parseInt(parts[0], 10) || 0));
    const minutes = Math.max(0, Math.min(59, parseInt(parts[1], 10) || 0));
    return hours * 60 + minutes;
  }

  Process {
    id: nightLightProcess

    onExited: function (exitCode, exitStatus) {
      if (root.enabled && exitCode !== 0) {
        Logger.w("NightLightService", "quicknix-nightlight exited with code " + exitCode + " status " + exitStatus);
      }
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.enabled && !root.forced
    onTriggered: root.scheduleRestart()
  }
}
