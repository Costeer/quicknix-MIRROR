#!/usr/bin/env python3
import json
import sys
import urllib.request
from datetime import datetime, timezone

try:
    import icalendar
    import recurring_ical_events
except ImportError:
    print("[]", end="")
    sys.exit(0)

def parse_args():
    config_json = None
    start_epoch = None
    end_epoch = None
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--config-json" and i + 1 < len(sys.argv):
            config_json = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == "--from" and i + 1 < len(sys.argv):
            start_epoch = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == "--to" and i + 1 < len(sys.argv):
            end_epoch = int(sys.argv[i + 1])
            i += 2
        else:
            i += 1
    return config_json, start_epoch, end_epoch

def load_config(raw_json):
    try:
        return json.loads(raw_json)
    except Exception:
        return []

def fetch_ics(url, timeout=15):
    req = urllib.request.Request(url, headers={"User-Agent": "quicknix-calendar/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()

def get_events(cal, start_dt, end_dt):
    try:
        return recurring_ical_events.of(cal).between(start_dt, end_dt)
    except Exception:
        events = []
        for component in cal.walk():
            if component.name == "VEVENT":
                events.append(component)
        return events

def to_epoch(dt_val):
    if dt_val is None:
        return None
    if isinstance(dt_val, datetime):
        if dt_val.tzinfo is None:
            dt_val = dt_val.replace(tzinfo=timezone.utc)
        return int(dt_val.timestamp())
    return None

def extract_event(component, sub_name, sub_color):
    uid = str(component.get("UID", ""))
    summary = str(component.get("SUMMARY", "(No title)"))
    location = str(component.get("LOCATION", ""))
    description = str(component.get("DESCRIPTION", ""))

    dtstart = component.get("DTSTART")
    dtend = component.get("DTEND")

    start_ts = None
    end_ts = None
    all_day = False

    if dtstart:
        val = dtstart.dt if hasattr(dtstart, "dt") else dtstart
        if hasattr(val, "date") and not hasattr(val, "hour"):
            date_val = val.date() if hasattr(val, "date") else val
            from datetime import date as date_type
            if isinstance(date_val, date_type):
                start_ts = int(datetime(date_val.year, date_val.month, date_val.day, tzinfo=timezone.utc).timestamp())
            else:
                start_ts = to_epoch(val)
            all_day = True
        else:
            start_ts = to_epoch(val)
    if dtend:
        val = dtend.dt if hasattr(dtend, "dt") else dtend
        if hasattr(val, "date") and not hasattr(val, "hour"):
            date_val = val.date() if hasattr(val, "date") else val
            from datetime import date as date_type
            if isinstance(date_val, date_type):
                end_ts = int(datetime(date_val.year, date_val.month, date_val.day, tzinfo=timezone.utc).timestamp())
            else:
                end_ts = to_epoch(val)
            all_day = True
        else:
            end_ts = to_epoch(val)

    if start_ts is not None and end_ts is None:
        end_ts = start_ts + (86400 if all_day else 3600)

    return {
        "uid": uid,
        "calendar": sub_name,
        "summary": summary,
        "start": start_ts or 0,
        "end": end_ts or 0,
        "location": location,
        "description": description,
        "allDay": all_day,
        "color": sub_color,
    }

def main():
    config_json, start_epoch, end_epoch = parse_args()
    if not config_json or start_epoch is None or end_epoch is None:
        print("[]", end="")
        return

    subscriptions = load_config(config_json)
    if not subscriptions:
        print("[]", end="")
        return

    start_dt = datetime.fromtimestamp(start_epoch, tz=timezone.utc)
    end_dt = datetime.fromtimestamp(end_epoch, tz=timezone.utc)

    all_events = []
    for sub in subscriptions:
        if not sub.get("enabled", True):
            continue
        url = sub.get("url", "")
        name = sub.get("name", "Subscription")
        color = sub.get("color", "")
        if not url:
            continue
        try:
            raw = fetch_ics(url)
            cal = icalendar.Calendar.from_ical(raw)
            events = get_events(cal, start_dt, end_dt)
            for component in events:
                if hasattr(component, "name") and component.name == "VEVENT":
                    evt = extract_event(component, name, color)
                    if evt["start"] and start_epoch <= evt["start"] <= end_epoch:
                        all_events.append(evt)
        except Exception as e:
            print(f"Error fetching {name}: {e}", file=sys.stderr)
            continue

    all_events.sort(key=lambda x: x["start"])
    print(json.dumps(all_events))

if __name__ == "__main__":
    main()
