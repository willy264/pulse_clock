"""Extract settled transition snapshots from the recorded application VCD.

Usage: python docs/waveforms/extract_application_waveforms.py PATH_TO_VCD
The CSV needs only Python's standard library. If matplotlib is installed, a
standalone timing figure is also generated. This is not needed to run RTL tests.
"""

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


ROOT = "water_tank_system_tb"
SIGNALS = [
    "reset", "enable", "source_available", "fault_clear", "noise_mask",
    "direct_sensors", "directed_value", "sensor_in", "sensor_debounced",
    "sensor_valid", "pump_enable", "flow_present", "timer_busy", "timer_done",
    "dry_run_detected", "protection_active", "tank_level", "test_passed",
]
FIELDS = {name: f"{ROOT}.{name}" for name in SIGNALS}
FIELDS.update({"controller_state": f"{ROOT}.dut.state",
               "timer_start": f"{ROOT}.dut.timer_start",
               "timer_cancel": f"{ROOT}.dut.timer_cancel"})
BINARY_FIELDS = {"noise_mask", "directed_value", "sensor_in",
                 "sensor_debounced", "sensor_valid"}
STATE_NAMES = {0: "IDLE", 1: "WAIT_RESPONSE", 2: "FILLING", 3: "PROTECTED"}


def extract(vcd_path):
    raw = vcd_path.read_bytes()
    text = raw.decode("ascii")
    if not re.search(r"\$timescale\s+1ps\s+\$end", text):
        raise ValueError("This extraction expects the recorded 1 ps VCD timebase")
    declarations = {}
    scope = []
    lines = iter(text.splitlines())
    for line in lines:
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "$scope":
            scope.append(parts[2])
        elif parts[0] == "$upscope":
            scope.pop()
        elif parts[0] == "$var":
            width, symbol, name = int(parts[2]), parts[3], parts[4]
            suffix = parts[5] if parts[5] != "$end" else ""
            full_name = ".".join(scope + [name])
            declarations.setdefault(full_name, []).append((symbol, width, suffix))
        elif parts[0] == "$enddefinitions":
            break
    required = set(FIELDS.values()) | {f"{ROOT}.cycle_count"}
    missing = required - declarations.keys()
    if missing:
        raise ValueError(f"Missing recorded signals: {sorted(missing)}")
    values = {}
    rows = []
    current_time = 0

    def read_signal(name):
        bits = declarations[name]
        if len(bits) == 1:
            symbol, width, _ = bits[0]
            result = values.get(symbol, "x").lower()
            result = result.rjust(width, result[0] if result[0] in "xz" else "0")
        else:
            ordered = sorted(bits, key=lambda entry: int(entry[2][1:-1]), reverse=True)
            result = "".join(values.get(symbol, "x").lower()
                             for symbol, _, _ in ordered)
        return result if any(bit in "xz" for bit in result) else int(result, 2)

    def flush():
        if not values:
            return
        row = {"time_ns": f"{current_time / 1000:g}",
               "cycle_count": read_signal(f"{ROOT}.cycle_count")}
        for field, name in FIELDS.items():
            value = read_signal(name)
            if field in BINARY_FIELDS and isinstance(value, int):
                value = format(value, "02b")
            elif field == "controller_state" and isinstance(value, int):
                value = STATE_NAMES[value]
            row[field] = value
        if not rows or any(row[key] != rows[-1][key] for key in FIELDS):
            rows.append(row)

    for line in lines:
        line = line.strip()
        if not line or line.startswith("$"):
            continue
        if line.startswith("#"):
            flush()
            current_time = int(line[1:])
        elif line[0] in "01xXzZ":
            values[line[1:]] = line[0]
        elif line[0] in "bB":
            value, symbol = line[1:].split()
            values[symbol] = value
    flush()
    return rows, {"source_vcd": str(vcd_path), "sha256": hashlib.sha256(raw).hexdigest(),
                  "bytes": len(raw), "timescale": "1 ps", "end_ns": current_time / 1000,
                  "transition_rows": len(rows)}


def plot(rows, output_path):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib unavailable; CSV extraction completed without a plot")
        return

    pump_starts = transitions(rows, "pump_enable", 1)
    pump_stops = transitions(rows, "pump_enable", 0)
    protection = transitions(rows, "dry_run_detected", 1)[0]
    first_stop = next(row for row in pump_stops if float(row["time_ns"]) > float(pump_starts[0]["time_ns"]))
    dry_start = next(row for row in reversed(pump_starts)
                     if float(row["time_ns"]) < float(protection["time_ns"]))
    windows = [(0, float(first_stop["time_ns"]) + 60, "Normal model filling"),
               (float(dry_start["time_ns"]) - 120, float(protection["time_ns"]) + 120,
                "Absent source: noise rejected, window expires")]
    lanes = [("sensor_in", "Raw thresholds", 3),
             ("sensor_debounced", "Qualified thresholds", 3),
             ("pump_enable", "Pump command", 1),
             ("timer_busy", "Timer busy", 1),
             ("timer_done", "Timer done", 1),
             ("dry_run_detected", "Protection latched", 1)]
    colors = ["#3563B5", "#07917D", "#6A4CB4", "#2D708E", "#D47B15", "#BA3B48"]
    fig, axes = plt.subplots(2, 1, figsize=(12, 7.5), layout="constrained")
    fig.suptitle("PULSE application — measured ModelSim transitions", fontsize=15, weight="bold")
    for axis, (left, right, title) in zip(axes, windows):
        times = [left] + [float(row["time_ns"]) for row in rows
                          if left < float(row["time_ns"]) <= right] + [right]
        for index, ((field, label, maximum), color) in enumerate(zip(lanes, colors)):
            baseline = len(lanes) - index - 1
            samples = []
            for time_ns in times:
                sample = next((row[field] for row in reversed(rows)
                               if float(row["time_ns"]) <= time_ns), "x")
                if field in BINARY_FIELDS and isinstance(sample, str) and set(sample) <= {"0", "1"}:
                    sample = int(sample, 2)
                samples.append(baseline + 0.65 * sample / maximum
                               if isinstance(sample, int) else float("nan"))
            axis.step(times, samples, where="post", color=color, linewidth=1.8)
            axis.axhline(baseline, color="#dddddd", linewidth=0.5)
        axis.set_yticks([len(lanes) - i - 1 + 0.28 for i in range(len(lanes))],
                       [label for _, label, _ in lanes])
        axis.set_xlim(left, right)
        axis.set_ylim(-0.15, len(lanes) - 0.1)
        axis.set_title(title, loc="left", fontsize=12)
        axis.set_xlabel("Simulation time (ns)")
        axis.grid(axis="x", alpha=0.2)
        axis.spines[["top", "right", "left"]].set_visible(False)
        axis.tick_params(axis="y", length=0)
    axes[0].text(0.99, 1.0, "Threshold bus levels: 00 LOW · 01 MID · 11 FULL",
                 transform=axes[0].transAxes, ha="right", va="bottom", fontsize=9, color="#444444")
    axes[1].text(0.99, 1.0, "Fixture: 20 ns clock · 3-cycle debounce · 64-cycle window",
                 transform=axes[1].transAxes, ha="right", va="bottom", fontsize=9, color="#444444")
    fig.savefig(output_path, dpi=170)
    plt.close(fig)


def transitions(rows, field, wanted=None):
    previous = None
    found = []
    for row in rows:
        value = row[field]
        if value != previous and (wanted is None or value == wanted):
            found.append(row)
        previous = value
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    args = parser.parse_args()
    rows, metadata = extract(args.vcd)
    output_directory = Path(__file__).resolve().parent
    with (output_directory / "application_events.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    plot(rows, output_directory / "application_timing.png")
    print(json.dumps(metadata, indent=2))
    for field in ("reset", "enable", "noise_mask", "fault_clear", "pump_enable",
                  "sensor_debounced", "timer_done", "dry_run_detected", "controller_state"):
        print(field + ": " + ", ".join(f"{row['time_ns']}={row[field]}"
                                       for row in transitions(rows, field)))


if __name__ == "__main__":
    main()
