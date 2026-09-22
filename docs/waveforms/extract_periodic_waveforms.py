"""Extract actual periodic-generator and concurrency waveforms from one run.

Usage: python docs/waveforms/extract_periodic_waveforms.py BUILD_RUN_DIRECTORY
The run must contain pulse_periodic_smoke_tb.vcd, pulse_periodic_tb.vcd, and
pulse_top_tb.vcd. CSV/JSON extraction uses only the Python standard library;
installed matplotlib additionally produces standalone PNG figures. No ideal
waveforms are generated: every plotted sample comes from the recorded VCD.
"""

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


def fields(root, names, instance):
    result = {name: f"{root}.{name}" for name in names}
    result.update({name: f"{root}.{instance}.{name}"
                   for name in ("active", "captured_period", "remaining")})
    return result


COMMON = ["reset", "enable", "periodic_enable", "cfg_period_cycles",
          "periodic_tick", "test_passed"]
FIELDS = {
    "smoke": fields("pulse_periodic_smoke_tb", COMMON, "dut"),
    "consumer": fields("pulse_periodic_tb", COMMON +
                       ["case_id", "consumer_count", "checker_errors"], "dut"),
    "concurrency": fields("pulse_top_tb", COMMON +
                          ["timer_start", "timer_cancel", "cfg_timer_cycles",
                           "timer_busy", "timer_done", "sensor_in",
                           "sensor_debounced", "sensor_valid"], "dut.u_periodic"),
}
INPUTS = {"smoke": "pulse_periodic_smoke_tb.vcd",
          "consumer": "pulse_periodic_tb.vcd", "concurrency": "pulse_top_tb.vcd"}


def extract(vcd_path, wanted):
    raw = vcd_path.read_bytes()
    text = raw.decode("ascii")
    scale = re.search(r"\$timescale\s+(1|10|100)\s*(s|ms|us|ns|ps|fs)\s+\$end", text)
    if not scale:
        raise ValueError(f"Unsupported or missing VCD timescale: {vcd_path}")
    magnitude, unit = int(scale[1]), scale[2]
    scale_ns = magnitude * {"s": 1e9, "ms": 1e6, "us": 1e3,
                            "ns": 1, "ps": 1e-3, "fs": 1e-6}[unit]
    declarations, scope = {}, []
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
            declarations.setdefault(".".join(scope + [name]), []).append((symbol, width, suffix))
        elif parts[0] == "$enddefinitions":
            break
    missing = set(wanted.values()) - declarations.keys()
    if missing:
        raise ValueError(f"Missing recorded signals in {vcd_path}: {sorted(missing)}")
    values, rows = {}, []
    timestamp = 0

    def read_signal(name):
        entries = declarations[name]
        if len(entries) == 1:
            symbol, width, _ = entries[0]
            bits = values.get(symbol, "x").lower()
            bits = bits.rjust(width, bits[0] if bits[0] in "xz" else "0")
        else:
            # ModelSim records some buses as one declaration per bit.
            ordered = sorted(entries, key=lambda item: int(item[2][1:-1]), reverse=True)
            bits = "".join(values.get(symbol, "x").lower() for symbol, _, _ in ordered)
        return bits if any(bit in "xz" for bit in bits) else int(bits, 2)

    def flush():
        if not values:
            return
        row = {"time_ns": timestamp * scale_ns}
        row.update({field: read_signal(name) for field, name in wanted.items()})
        if not rows or any(row[field] != rows[-1][field] for field in wanted):
            rows.append(row)

    for line in lines:
        line = line.strip()
        if not line or line.startswith("$"):
            continue
        if line.startswith("#"):
            next_timestamp = int(line[1:])
            if next_timestamp != timestamp:
                flush()
                timestamp = next_timestamp
        elif line[0] in "01xXzZ":
            values[line[1:]] = line[0]
        elif line[0] in "bB":
            value, symbol = line[1:].split()
            values[symbol] = value
    flush()
    if not rows or rows[-1]["test_passed"] != 1:
        raise ValueError(f"Recorded bench did not reach test_passed=1: {vcd_path}")
    return rows, {
        "source_vcd": str(vcd_path), "sha256": hashlib.sha256(raw).hexdigest(),
        "bytes": len(raw), "timescale": f"{magnitude} {unit}",
        "end_ns": timestamp * scale_ns, "recorded_transition_rows": len(rows),
    }


def crop(rows, left, right):
    """Retain the actual last snapshot before the selected interval as context."""
    context = next(row for row in reversed(rows) if row["time_ns"] <= left)
    return [context] + [row for row in rows if left < row["time_ns"] <= right]


def transitions(rows, field, wanted=None):
    previous, found = None, []
    for row in rows:
        value = row[field]
        if value != previous and (wanted is None or value == wanted):
            found.append({"time_ns": row["time_ns"], "value": value})
        previous = value
    return found


def draw(axis, rows, left, right, lanes, title):
    times = [left] + [row["time_ns"] for row in rows if left < row["time_ns"] <= right]
    if times[-1] < right:
        times.append(right)
    colors = ["#3563B5", "#07917D", "#6A4CB4", "#D47B15", "#BA3B48", "#2D708E"]
    for index, (field, label, maximum) in enumerate(lanes):
        baseline = len(lanes) - index - 1
        samples = []
        for time_ns in times:
            value = next((row[field] for row in reversed(rows) if row["time_ns"] <= time_ns), "x")
            samples.append(baseline + 0.65 * value / maximum
                           if isinstance(value, int) else float("nan"))
        axis.step(times, samples, where="post", color=colors[index % len(colors)], linewidth=1.65)
        axis.axhline(baseline, color="#dddddd", linewidth=0.5)
    axis.set_yticks([len(lanes) - i - 1 + 0.28 for i in range(len(lanes))],
                   [label for _, label, _ in lanes])
    axis.set_xlim(left, right)
    axis.set_ylim(-0.15, len(lanes) - 0.05)
    axis.set_title(title, loc="left", fontsize=11)
    axis.set_xlabel("Simulation time (ns)")
    axis.grid(axis="x", alpha=0.22)
    axis.spines[["top", "right", "left"]].set_visible(False)
    axis.tick_params(axis="y", length=0, labelsize=9)


def plot(selected, metadata, output):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib unavailable; CSV/JSON evidence extracted without figures")
        return []
    figure, axes = plt.subplots(2, 1, figsize=(13, 9.5), layout="constrained")
    figure.suptitle("PULSE periodic events - measured ModelSim waveforms", fontsize=15, weight="bold")
    lanes = [("reset", "Reset", 1), ("enable", "Global enable", 1),
             ("periodic_enable", "Periodic enable", 1),
             ("cfg_period_cycles", "Live period (0..7)", 7),
             ("captured_period", "Captured period (0..4)", 4),
             ("periodic_tick", "Registered tick", 1)]
    draw(axes[0], selected["smoke"], 0, metadata["smoke"]["end_ns"], lanes,
         "Smoke: P=3 repeats despite changed configuration; P=2 / P=1 and reset/disable")
    lanes = [("reset", "Reset", 1), ("periodic_enable", "Periodic enable", 1),
             ("cfg_period_cycles", "Live period (0..15)", 15),
             ("captured_period", "Captured period (0..3)", 3),
             ("periodic_tick", "Registered tick", 1),
             ("consumer_count", "Consumer count (0..3)", 3)]
    window = metadata["consumer"]["selection"]
    draw(axes[1], selected["consumer"], window["start_ns"], window["end_ns"], lanes,
         "Independent O02, P=3: 60 ns event spacing; consumer observes each tick 20 ns later")
    figure.savefig(output / "periodic_timing.png", dpi=170)
    plt.close(figure)

    figure, axis = plt.subplots(figsize=(14, 10), layout="constrained")
    figure.suptitle("PULSE concurrency - measured ModelSim waveforms", fontsize=15, weight="bold")
    lanes = [("reset", "Reset", 1), ("enable", "Global enable", 1),
             ("periodic_enable", "Periodic enable", 1),
             ("cfg_period_cycles", "Live period (0..5)", 5),
             ("captured_period", "Captured period (0..4)", 4),
             ("periodic_tick", "Registered tick", 1),
             ("timer_start", "Timer start", 1), ("timer_cancel", "Timer cancel", 1),
             ("timer_busy", "Timer busy", 1), ("timer_done", "Timer done", 1),
             ("sensor_in", "Raw sensors (00..11)", 3),
             ("sensor_debounced", "Qualified sensors (00..11)", 3),
             ("sensor_valid", "Sensor validity (00..11)", 3)]
    window = metadata["concurrency"]["selection"]
    draw(axis, selected["concurrency"], window["start_ns"], window["end_ns"], lanes,
         "P08-P11: fixed recurring phase with timer controls / sensor noise; local and global restart")
    figure.savefig(output / "periodic_concurrency.png", dpi=170)
    plt.close(figure)
    return ["periodic_timing.png", "periodic_concurrency.png"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_directory", type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    rows, metadata = {}, {}
    for key, filename in INPUTS.items():
        rows[key], metadata[key] = extract(args.run_directory / filename, FIELDS[key])
    selected = {"smoke": rows["smoke"]}
    capture = next(row for row in rows["consumer"] if row["case_id"] == 2
                   and row["active"] == 1 and row["captured_period"] == 3)
    finish = next(row for row in rows["consumer"] if row["time_ns"] > capture["time_ns"]
                  and row["active"] == 0)
    consumer_left, consumer_right = capture["time_ns"] - 20, finish["time_ns"]
    top_start = next(row for row in rows["concurrency"] if row["periodic_enable"] == 1)
    top_left, top_right = max(0, top_start["time_ns"] - 40), metadata["concurrency"]["end_ns"]
    selected["consumer"] = crop(rows["consumer"], consumer_left, consumer_right)
    selected["concurrency"] = crop(rows["concurrency"], top_left, top_right)
    windows = {"smoke": (0, metadata["smoke"]["end_ns"]),
               "consumer": (consumer_left, consumer_right), "concurrency": (top_left, top_right)}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for key, snapshots in selected.items():
        filename = f"periodic_{key}_events.csv"
        with (args.output_dir / filename).open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(snapshots[0]))
            writer.writeheader()
            writer.writerows(snapshots)
        metadata[key]["selection"] = {"start_ns": windows[key][0], "end_ns": windows[key][1],
                                       "transition_rows": len(snapshots), "csv": filename}
        metadata[key]["selected_tick_rises"] = transitions(snapshots, "periodic_tick", 1)
    metadata["consumer"]["selected_consumer_changes"] = transitions(selected["consumer"], "consumer_count")
    figures = plot(selected, metadata, args.output_dir)
    report = {"contract": "OSC-CONTRACT-1", "run_directory": str(args.run_directory),
              "method": "Settled VCD snapshots; clock-only changes omitted. Crops retain one actual preceding snapshot.",
              "figures": figures, "recordings": metadata}
    with (args.output_dir / "periodic_metadata.json").open("w", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
