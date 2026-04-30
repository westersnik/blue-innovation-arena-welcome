#!/usr/bin/env python3
"""
Generate realistic cold-chain journey data for GS1 Nordic Summit demo.
Simulates a Carlsberg beer bottle journey from Copenhagen to Lillestrøm.

Journey:
  1. Carlsberg Brewery, Fredericia DK   (production, ~18°C → cooled to 4°C)
  2. Cold Storage, Kastrup Airport DK   (3.9°C)
  3. Air/truck to Göteborg              (4.5°C, slight warm in transit)
  4. Fredrikstad Cold Terminal NO       (4.2°C)
  5. Oslo Distribution Centre           (3.8°C)
  6. Refrigerated Transport E6 North    (5.8°C – brief warm spike)
  7. Venue Cold Room, Lillestrøm NO     (4.0°C)
  8. Bar Fridge, Summit Hall            (5.0°C)
  9. Handed to guest                    (5.5°C – current)
"""

import json, random, os
from datetime import datetime, timedelta, timezone

# Event day: 14 May 2025, 14:00 UTC (GS1 Nordic Summit)
NOW = datetime(2025, 5, 14, 14, 0, 0, tzinfo=timezone.utc)
START = NOW - timedelta(hours=168)  # 7 days before

# Venue: Radisson Blu Plaza Hotel, Sonja Henies plass 3, 0185 Oslo
# Coordinates from OSM: 59.9124097, 10.7559434
VENUE_LAT = 59.9124097
VENUE_LON = 10.7559434

# Waypoints: (lat, lon, location_name, temp_celsius, hours_from_start)
WAYPOINTS = [
    (55.5607,  9.7520,  "Carlsberg Brewery, Fredericia DK",                  18.5,   0),
    (55.5607,  9.7520,  "Carlsberg Brewery, Fredericia DK",                   8.0,   4),
    (55.5607,  9.7520,  "Carlsberg Brewery, Fredericia DK",                   4.5,   8),
    (55.6298, 12.6561,  "Cold Storage, Kastrup Airport DK",                   3.9,  20),
    (55.6298, 12.6561,  "Cold Storage, Kastrup Airport DK",                   3.8,  30),
    (57.7089, 11.9746,  "Göteborg Distribution Hub, SE",                      5.2,  42),
    (57.7089, 11.9746,  "Göteborg Distribution Hub, SE",                      4.8,  48),
    (59.2167, 10.9333,  "Fredrikstad Cold Terminal, NO",                      4.3,  60),
    (59.9200, 10.8100,  "Oslo Distribution Centre, Alnabru NO",               3.9,  72),
    (59.9200, 10.8100,  "Oslo Distribution Centre, Alnabru NO",               3.8,  84),
    (59.9200, 10.8100,  "Oslo Distribution Centre, Alnabru NO",               4.0,  96),
    (59.9180, 10.7800,  "Refrigerated Transport, Oslo city centre",           5.9, 108),
    (VENUE_LAT, VENUE_LON, "Venue Cold Room, Radisson Blu Plaza Oslo",        4.2, 120),
    (VENUE_LAT, VENUE_LON, "Venue Cold Room, Radisson Blu Plaza Oslo",        4.0, 132),
    (VENUE_LAT, VENUE_LON, "Venue Cold Room, Radisson Blu Plaza Oslo",        3.9, 144),
    (VENUE_LAT, VENUE_LON, "Venue Cold Room, Radisson Blu Plaza Oslo",        4.1, 156),
    (VENUE_LAT, VENUE_LON, "Bar Fridge, GS1 Nordic Summit",                  5.0, 162),
    (VENUE_LAT, VENUE_LON, "Bar Fridge, GS1 Nordic Summit",                  5.2, 165),
    (VENUE_LAT, VENUE_LON, "Handed to guest · Radisson Blu Plaza Oslo",      5.5, 167),
]


def make_journey(seed_offset=0):
    rng = random.Random(42 + seed_offset)
    journey = []

    for i, (lat, lon, name, temp_target, hours) in enumerate(WAYPOINTS):
        next_hours = WAYPOINTS[i + 1][4] if i < len(WAYPOINTS) - 1 else hours + 1
        n_readings = 2 if i < len(WAYPOINTS) - 1 else 1

        for j in range(n_readings):
            frac = j / n_readings
            ts = START + timedelta(hours=hours + frac * (next_hours - hours))

            if i < len(WAYPOINTS) - 1:
                next_lat, next_lon = WAYPOINTS[i + 1][0], WAYPOINTS[i + 1][1]
                cur_lat = lat + frac * (next_lat - lat)
                cur_lon = lon + frac * (next_lon - lon)
            else:
                cur_lat, cur_lon = lat, lon

            noise = rng.uniform(-0.25, 0.25)
            temp = round(temp_target + noise, 2)

            journey.append({
                "timestamp": ts.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00"),
                "temperature": temp,
                "battery_level": max(55, 100 - int(hours / 168 * 40) + rng.randint(-3, 3)),
                "latitude": round(cur_lat + rng.uniform(-0.0003, 0.0003), 8),
                "longitude": round(cur_lon + rng.uniform(-0.0003, 0.0003), 8),
                "location_name": name,   # extra field for display
            })

    return journey


def make_tracker_payload(device_name, seed_offset=0):
    journey = make_journey(seed_offset)
    last = journey[-1]
    return {
        "device_id": f"dev-{device_name.lower().replace(' ', '-')}",
        "name": device_name,
        "grai": f"urn:epc:id:grai:7070123.00.{'000009' if '09' in device_name else '000003'}",
        "type": None,
        "status": "active",
        "location": {
            "lat": last["latitude"],
            "lon": last["longitude"],
            "ts": last["timestamp"],
        },
        "temperature": {
            "current": last["temperature"],
            "unit": "celsius",
            "ts": last["timestamp"],
        },
        "journey": journey,
        "total_readings": len(journey),
        "period_hours": 168,
    }


os.makedirs("V2/data", exist_ok=True)

for name, offset in [("SR-Tracker-09", 0), ("SR-Tracker-03", 7)]:
    payload = make_tracker_payload(name, seed_offset=offset)
    fname = f"V2/data/{name.lower().replace('-', '-')}.json"
    with open(fname, "w") as f:
        json.dump(payload, f, indent=2)
    print(f"✅ {fname}: {len(payload['journey'])} readings, current temp: {payload['temperature']['current']}°C")
    print(f"   Route: {payload['journey'][0]['location_name']} → {payload['journey'][-1]['location_name']}")
    print(f"   Coords: ({payload['journey'][0]['latitude']:.4f},{payload['journey'][0]['longitude']:.4f}) → ({payload['journey'][-1]['latitude']:.4f},{payload['journey'][-1]['longitude']:.4f})")
    print()
