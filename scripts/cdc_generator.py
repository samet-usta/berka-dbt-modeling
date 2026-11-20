"""CDC batch generator for the Berka dataset.

Reads the current state from DuckDB raw, simulates client and account
changes for one batch and writes JSON lines files to data/landing/.

Usage: python scripts/cdc_generator.py <batch_id>
"""

import calendar
import json
import random
import sys
from datetime import datetime
from pathlib import Path

import duckdb

DB_PATH = "berka.duckdb"
LANDING_PATH = Path("data/landing")
BASE_SEED = 42
FREQUENCIES = ["POPLATEK MESICNE", "POPLATEK TYDNE", "POPLATEK PO OBRATU"]

# Edge case IDs are far above max ID, so they never exist
EDGE_CASE_ID_OFFSET = 100000

# Business columns only; updated_at and _loaded_at are written by apply_cdc_batch.py
TABLE_QUERIES = {
    "client": "select client_id, birth_number, district_id from raw.client",
    "account": "select account_id, district_id, frequency, date from raw.account",
    "district": "select A1 as district_id from raw.district",
}

TABLE_KEYS = {
    "client": "client_id",
    "account": "account_id",
    "district": "district_id",
}


def load_current_state(con):
    """Read raw tables into dictionaries: {table: {id: row_dict}}."""
    state = {}
    for table_name, query in TABLE_QUERIES.items():
        result = con.execute(query)

        column_names = []
        for column in result.description:
            column_names.append(column[0])

        key_column = TABLE_KEYS[table_name]
        table_state = {}
        for row in result.fetchall():
            row_dict = dict(zip(column_names, row))
            key = row_dict[key_column]
            table_state[key] = row_dict

        state[table_name] = table_state
    return state


def random_change_ts(batch_id, rng):
    """Random timestamp inside the calendar month of the batch (batch 1 = 1999-01)."""
    year = 1999 + (batch_id - 1) // 12
    month = (batch_id - 1) % 12 + 1
    days_in_month = calendar.monthrange(year, month)[1]

    day = rng.randint(1, days_in_month)
    hour = rng.randint(0, 23)
    minute = rng.randint(0, 59)
    second = rng.randint(0, 59)

    change_ts = datetime(year, month, day, hour, minute, second)
    return change_ts.isoformat()


def get_sorted_ids(table_state):
    """IDs sorted as numbers, so rng picks are the same in every run."""
    return sorted(table_state.keys(), key=int)


def get_max_id(table_state):
    max_id = 0
    for key in table_state:
        if int(key) > max_id:
            max_id = int(key)
    return max_id


def make_change(row, op_type, batch_id, rng):
    """Full row image plus CDC columns."""
    change = dict(row)
    change["op_type"] = op_type
    change["change_ts"] = random_change_ts(batch_id, rng)
    change["batch_id"] = batch_id
    return change


def random_birth_number(rng):
    """Berka format YYMMDD; for women the month is +50."""
    year = rng.randint(1940, 1980)
    month = rng.randint(1, 12)
    days_in_month = calendar.monthrange(year, month)[1]
    day = rng.randint(1, days_in_month)

    is_female = rng.random() < 0.5
    if is_female:
        month = month + 50

    yy = year % 100
    return f"{yy:02d}{month:02d}{day:02d}"


def generate_client_changes(state, batch_id, rng):
    """Address changes (U) and new clients (I)."""
    changes = []
    client_ids = get_sorted_ids(state["client"])
    district_ids = get_sorted_ids(state["district"])

    num_updates = rng.randint(5, 20)
    update_ids = rng.sample(client_ids, num_updates)
    for client_id in update_ids:
        row = dict(state["client"][client_id])
        old_district = row["district_id"]
        new_district = rng.choice(district_ids)
        while new_district == old_district:
            new_district = rng.choice(district_ids)
        row["district_id"] = new_district
        changes.append(make_change(row, "U", batch_id, rng))

    num_inserts = rng.randint(1, 5)
    next_id = get_max_id(state["client"]) + 1
    for i in range(num_inserts):
        row = {
            "client_id": str(next_id + i),
            "birth_number": random_birth_number(rng),
            "district_id": rng.choice(district_ids),
        }
        changes.append(make_change(row, "I", batch_id, rng))
    return changes


def generate_account_changes(state, batch_id, rng):
    """Statement frequency changes (U)."""
    changes = []
    account_ids = get_sorted_ids(state["account"])

    num_updates = rng.randint(5, 20)
    update_ids = rng.sample(account_ids, num_updates)
    for account_id in update_ids:
        row = dict(state["account"][account_id])
        old_frequency = row["frequency"]
        new_frequency = rng.choice(FREQUENCIES)
        while new_frequency == old_frequency:
            new_frequency = rng.choice(FREQUENCIES)
        row["frequency"] = new_frequency
        changes.append(make_change(row, "U", batch_id, rng))
    return changes


def ordered_change_ts_pair(batch_id, rng):
    """Two different change_ts values in the batch month, the earlier one first."""
    first_ts = random_change_ts(batch_id, rng)
    second_ts = random_change_ts(batch_id, rng)
    while second_ts == first_ts:
        second_ts = random_change_ts(batch_id, rng)

    if second_ts < first_ts:
        temp_ts = first_ts
        first_ts = second_ts
        second_ts = temp_ts

    return first_ts, second_ts


def add_same_key_twice(state, batch_id, rng, batch_changes):
    """Two clients move twice in one batch (U -> U)."""
    district_ids = get_sorted_ids(state["district"])

    client_updates = []
    for change in batch_changes["client"]:
        if change["op_type"] == "U":
            client_updates.append(change)

    moved_twice = rng.sample(client_updates, 2)
    for first_change in moved_twice:
        first_ts, second_ts = ordered_change_ts_pair(batch_id, rng)
        first_change["change_ts"] = first_ts

        second_change = dict(first_change)
        new_district = rng.choice(district_ids)
        while new_district == first_change["district_id"]:
            new_district = rng.choice(district_ids)
        second_change["district_id"] = new_district
        second_change["change_ts"] = second_ts
        batch_changes["client"].append(second_change)
        print("Edge case U -> U, client_id:", first_change["client_id"])


def add_missing_key_change(state, batch_id, rng, batch_changes):
    """Update for a client that does not exist."""
    client_ids = get_sorted_ids(state["client"])
    missing_client = dict(state["client"][rng.choice(client_ids)])
    missing_client["client_id"] = str(get_max_id(state["client"]) + EDGE_CASE_ID_OFFSET)
    batch_changes["client"].append(make_change(missing_client, "U", batch_id, rng))
    print("Edge case U on missing key, client_id:", missing_client["client_id"])


def add_edge_cases(state, batch_id, rng, batch_changes):
    """Batch 2: same key twice. Batch 3: update for a missing key."""
    if batch_id == 2:
        add_same_key_twice(state, batch_id, rng, batch_changes)
    elif batch_id == 3:
        add_missing_key_change(state, batch_id, rng, batch_changes)


def write_batch(table_name, batch_id, changes):
    """Write one batch of one table as JSON lines to the landing folder."""
    table_path = LANDING_PATH / table_name
    table_path.mkdir(parents=True, exist_ok=True)
    batch_path = table_path / f"batch_{batch_id:04d}.jsonl"

    with open(batch_path, "w", encoding="utf-8") as file:
        for change in changes:
            file.write(json.dumps(change) + "\n")
    return batch_path


def main():
    batch_id = int(sys.argv[1])
    # Seed per batch: the same batch_id and raw state give the same changes
    rng = random.Random(BASE_SEED + batch_id)

    con = duckdb.connect(DB_PATH, read_only=True)
    state = load_current_state(con)
    con.close()

    print(f"=== Batch {batch_id} ===")
    batch_changes = {
        "client": generate_client_changes(state, batch_id, rng),
        "account": generate_account_changes(state, batch_id, rng),
    }
    add_edge_cases(state, batch_id, rng, batch_changes)

    for table_name, changes in batch_changes.items():
        batch_path = write_batch(table_name, batch_id, changes)
        print(f"{table_name}: {len(changes)} rows -> {batch_path}")


if __name__ == "__main__":
    main()
