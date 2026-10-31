"""Extract HEIC/HEIF frames and Apple's h24 time-of-day schedule."""
import argparse
import base64
import json
import math
import plistlib
from pathlib import Path
import xml.etree.ElementTree as ET

import pillow_heif


def validate_schedule(entries, count):
    if not isinstance(entries, list) or not entries:
        raise ValueError("Schedule must be a nonempty list of {i: frame index, t: day fraction}.")
    result = []
    for entry in entries:
        index, time = entry['i'], entry['t']
        if type(index) is not int or not 0 <= index < count:
            raise ValueError(f"Invalid frame index: {index}")
        if isinstance(time, bool) or not isinstance(time, (float, int)) or not math.isfinite(time) or not 0 <= time < 1:
            raise ValueError(f"Invalid time fraction: {time}")
        result.append({'i': index, 't': time})
    result.sort(key=lambda entry: entry['t'])
    if len({entry['t'] for entry in result}) != len(result):
        raise ValueError("Schedule times must be unique.")
    return result


def extract(source, destination, override=None):
    heif = pillow_heif.open_heif(source)
    if override:
        entries = json.loads(Path(override).read_text(encoding='utf-8-sig'))
    else:
        entries = None
        for frame in heif:
            xmp = frame.info.get('xmp')
            if not xmp:
                continue
            root = ET.fromstring(xmp)
            key = '{http://ns.apple.com/namespace/1.0/}h24'
            payload = next((node.text or node.attrib.get(key) for node in root.iter()
                            if node.tag == key or key in node.attrib), None)
            if payload:
                entries = plistlib.loads(base64.b64decode(payload))['ti']
                break
        if entries is None:
            raise ValueError("No Apple h24 time metadata found. Solar-only HEIC, static HEIF, and other images need --schedule.")
    entries = validate_schedule(entries, len(heif))
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(heif):
        frame.to_pillow().convert('RGB').save(destination / f'{index}.jpg', quality=95)
    (destination / 'schedule.json').write_text(json.dumps(entries, indent=2), encoding='utf-8')
    print(f"Extracted {len(heif)} HEIC/HEIF frames; {len(entries)} scheduled changes.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--schedule', type=Path)
    args = parser.parse_args()
    extract(args.source, args.destination, args.schedule)
