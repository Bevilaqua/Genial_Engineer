#!/usr/bin/env python3
"""Generate synthetic CDC seed files for the scheduling case.

This script is optional. The repository already ships versioned CSVs in `seeds/`.
"""

import csv
import random
from datetime import date, datetime, timedelta
from pathlib import Path

random.seed(42)
SEEDS_DIR = Path(__file__).resolve().parents[1] / "seeds"
SEEDS_DIR.mkdir(parents=True, exist_ok=True)

base_dt = datetime(2026, 5, 1, 8, 0, 0)


def dt(i: int) -> str:
    return (base_dt + timedelta(minutes=i)).strftime("%Y-%m-%d %H:%M:%S")


def generate_children() -> None:
    rows = []
    tenant = "genialcare"
    for i in range(1, 81):
        cid = f"child_{i:03d}"
        rows.append([
            f"evt_child_{i:04d}",
            "I",
            dt(i * 2),
            dt(i * 2 + 1),
            cid,
            f"Child {i:03d}",
            tenant,
            "true",
        ])

    ev = 1000
    for i in range(1, 11):
        cid = f"child_{i:03d}"
        rows.append([
            f"evt_child_{ev:04d}",
            "U",
            dt(ev),
            dt(ev + 1),
            cid,
            f"Child {i:03d}",
            tenant,
            "false" if i % 2 == 0 else "true",
        ])
        ev += 1

    for i in range(76, 81):
        cid = f"child_{i:03d}"
        rows.append([
            f"evt_child_{ev:04d}",
            "D",
            dt(ev),
            dt(ev + 1),
            cid,
            f"Child {i:03d}",
            tenant,
            "false",
        ])
        ev += 1

    with (SEEDS_DIR / "cdc_children.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["event_id", "op", "source_updated_at", "ingested_at", "child_id", "child_name", "tenant_id", "is_active"])
        w.writerows(rows)


def generate_disciplines() -> list[str]:
    disciplines = [
        ("aba", "ABA", True),
        ("fono", "Fono", True),
        ("to", "Terapia Ocupacional", True),
        ("psico", "Psicologia", True),
        ("psicoped", "Psicopedagogia", True),
    ]
    rows = []
    for i, (did, name, active) in enumerate(disciplines, 1):
        rows.append([f"evt_disc_{i:03d}", "I", dt(200 + i), dt(210 + i), did, name, str(active).lower()])

    rows.append(["evt_disc_900", "U", dt(900), dt(901), "psicoped", "Psicopedagogia", "false"])
    rows.append(["evt_disc_901", "D", dt(902), dt(903), "to", "Terapia Ocupacional", "false"])

    with (SEEDS_DIR / "cdc_disciplines.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["event_id", "op", "source_updated_at", "ingested_at", "discipline_id", "discipline_name", "is_active"])
        w.writerows(rows)

    return [d[0] for d in disciplines]


def generate_workloads(child_ids: list[str], disc_ids: list[str]) -> None:
    statuses = ["draft", "validated", "cancelled"]
    rows = []
    event = 1

    for i in range(1, 421):
        wid = f"wl_{i:04d}"
        cid = random.choice(child_ids)
        did = random.choice(disc_ids)
        start = date(2026, 5, 1) + timedelta(days=random.randint(0, 40))
        end = start + timedelta(days=random.choice([20, 30, 45, 60]))
        hours = random.choice([1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20])
        status = random.choices(statuses, weights=[20, 65, 15])[0]

        rows.append([
            f"evt_wl_{event:05d}",
            "I",
            dt(3000 + event * 2),
            dt(3000 + event * 2 + 1),
            wid,
            cid,
            did,
            start.isoformat(),
            end.isoformat(),
            hours,
            status,
        ])
        event += 1

        if i % 8 == 0:
            rows.append([
                f"evt_wl_{event:05d}",
                "U",
                dt(3000 + event * 2),
                dt(3000 + event * 2 + 1),
                wid,
                cid,
                did,
                start.isoformat(),
                end.isoformat(),
                hours,
                random.choice(statuses),
            ])
            event += 1

        if i % 37 == 0:
            rows.append([
                f"evt_wl_{event:05d}",
                "D",
                dt(3000 + event * 2),
                dt(3000 + event * 2 + 1),
                wid,
                cid,
                did,
                start.isoformat(),
                end.isoformat(),
                hours,
                "cancelled",
            ])
            event += 1

    with (SEEDS_DIR / "cdc_prescription_workloads.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "event_id",
            "op",
            "source_updated_at",
            "ingested_at",
            "workload_id",
            "child_id",
            "discipline_id",
            "valid_from",
            "valid_to",
            "prescribed_hours_per_week",
            "status",
        ])
        w.writerows(rows)


def generate_schedules(child_ids: list[str], disc_ids: list[str]) -> None:
    weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    statuses = ["active", "cancelled", "paused"]
    starts = ["08:00", "08:30", "09:00", "09:30", "10:00", "11:00", "13:00", "14:00", "15:00", "16:00"]

    rows = []
    event = 1

    for i in range(1, 1601):
        sid = f"sch_{i:05d}"
        cid = random.choice(child_ids)
        did = random.choice(disc_ids)
        weekday = random.choice(weekdays)
        start_time = random.choice(starts)

        sh, sm = map(int, start_time.split(":"))
        delta = random.choice([30, 45, 60, 90, 120])
        total = min(sh * 60 + sm + delta, 22 * 60)
        eh, em = divmod(total, 60)
        end_time = f"{eh:02d}:{em:02d}"

        valid_from = date(2026, 5, 1) + timedelta(days=random.randint(0, 60))
        valid_to = valid_from + timedelta(days=random.choice([14, 30, 45, 60]))
        status = random.choices(statuses, weights=[70, 15, 15])[0]

        rows.append([
            f"evt_sch_{event:05d}",
            "I",
            dt(7000 + event * 2),
            dt(7000 + event * 2 + 1),
            sid,
            cid,
            did,
            weekday,
            start_time,
            end_time,
            valid_from.isoformat(),
            valid_to.isoformat(),
            status,
        ])
        event += 1

        if i % 5 == 0:
            rows.append([
                f"evt_sch_{event:05d}",
                "U",
                dt(7000 + event * 2),
                dt(7000 + event * 2 + 1),
                sid,
                cid,
                did,
                weekday,
                start_time,
                end_time,
                valid_from.isoformat(),
                valid_to.isoformat(),
                random.choice(statuses),
            ])
            event += 1

        if i % 41 == 0:
            rows.append([
                f"evt_sch_{event:05d}",
                "D",
                dt(7000 + event * 2),
                dt(7000 + event * 2 + 1),
                sid,
                cid,
                did,
                weekday,
                start_time,
                end_time,
                valid_from.isoformat(),
                valid_to.isoformat(),
                "cancelled",
            ])
            event += 1

    with (SEEDS_DIR / "cdc_weekly_schedules.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "event_id",
            "op",
            "source_updated_at",
            "ingested_at",
            "schedule_id",
            "child_id",
            "discipline_id",
            "weekday",
            "start_time",
            "end_time",
            "valid_from",
            "valid_to",
            "status",
        ])
        w.writerows(rows)


if __name__ == "__main__":
    generate_children()
    disciplines = generate_disciplines()
    children = [f"child_{i:03d}" for i in range(1, 81)]
    generate_workloads(children, disciplines)
    generate_schedules(children, disciplines)
    print("Seed files generated under seeds/")
