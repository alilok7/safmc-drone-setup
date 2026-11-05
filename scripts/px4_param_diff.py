"""Compare two PX4 parameter files (QGroundControl .params format).

What it does: prints every parameter whose value differs between file A and file B, plus the ones
that exist in only one of them. Sorted by name, so related settings (MAV_*, EKF2_*, PWM_*) sit together.

Why it exists: before loading a parameter file onto a drone we want to see exactly what will
change, and after a flight we want to know if a drone's setup drifted from a known-good file.

Read-only: it only reads the two files.

Usage:  python scripts/px4_param_diff.py <A.params> <B.params> [--prefix EKF2_ --prefix MAV_]
"""
import argparse


def load(path):
    params = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.split()
            if len(parts) < 5 or line.startswith("#"):
                continue
            params[parts[2]] = float(parts[3])
    return params


def fmt(v):
    return str(int(v)) if v is not None and v.is_integer() else f"{v:.6g}" if v is not None else "-"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--prefix", action="append", default=[], help="only show these name prefixes")
    args = ap.parse_args()

    a, b = load(args.a), load(args.b)
    names = sorted(set(a) | set(b))
    if args.prefix:
        names = [n for n in names if n.startswith(tuple(args.prefix))]
    # Tolerance: QGC writes floats with limited digits, so ignore tiny rounding differences.
    diff = [n for n in names if n in a and n in b and abs(a[n] - b[n]) > 1e-4 * max(1, abs(a[n]))]
    only_a = [n for n in names if n not in b]
    only_b = [n for n in names if n not in a]

    print(f"A = {args.a} ({len(a)} params)\nB = {args.b} ({len(b)} params)\n")
    print(f"{len(diff)} differ:")
    for n in diff:
        print(f"  {n:<18} A={fmt(a[n]):<14} B={fmt(b[n])}")
    for label, lst in (("only in A", only_a), ("only in B", only_b)):
        if lst:
            print(f"\n{len(lst)} {label}: " + ", ".join(lst))


if __name__ == "__main__":
    main()
