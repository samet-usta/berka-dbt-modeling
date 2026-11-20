"""Apply one CDC batch from data/landing/ to the DuckDB raw schema.

Applies I/U/D in change_ts order, sets updated_at = change_ts and
appends every change to raw.<table>_changes.

Usage: python scripts/apply_cdc_batch.py <batch_id>
"""

import json
import sys
from datetime import datetime
from pathlib import Path

import duckdb

DB_PATH = "berka.duckdb"
LANDING_PATH = Path("data/landing")
CDC_COLUMNS = ["op_type", "change_ts", "batch_id"]
TABLE_KEYS = {
    "client": "client_id",
    "account": "account_id",
}


def read_batch(table_name, batch_id):
    """Read one JSON lines batch file into a list of dictionaries."""
    batch_path = LANDING_PATH / table_name / f"batch_{batch_id:04d}.jsonl"
    changes = []
    with open(batch_path, encoding="utf-8") as file:
        for line in file:
            change = json.loads(line)
            change["change_ts"] = datetime.fromisoformat(change["change_ts"])
            changes.append(change)
    return changes


def get_change_ts(change):
    """Sort key: changes are applied in change_ts order."""
    return change["change_ts"]


def get_data_columns(change):
    data_columns = []
    for column in change.keys():
        if column not in CDC_COLUMNS:
            data_columns.append(column)
    return data_columns


def quote_columns(columns):
    """Column list for SQL; quotes protect names like "date"."""
    quoted = []
    for column in columns:
        quoted.append(f'"{column}"')
    return ", ".join(quoted)


def append_to_change_log(con, table_name, batch_id, changes, data_columns):
    """Keep every change, also intermediate versions, in raw.<table>_changes."""
    changes_table = f"raw.{table_name}_changes"

    column_definitions = []
    for column in data_columns:
        column_definitions.append(f'"{column}" VARCHAR')
    column_definitions.append("op_type VARCHAR")
    column_definitions.append("change_ts TIMESTAMP")
    column_definitions.append("batch_id INTEGER")
    column_definitions.append("_loaded_at TIMESTAMP WITH TIME ZONE")
    con.execute(f"CREATE TABLE IF NOT EXISTS {changes_table} ({', '.join(column_definitions)})")

    # A re-run of the same batch replaces it, it does not duplicate it
    con.execute(f"DELETE FROM {changes_table} WHERE batch_id = ?", [batch_id])

    all_columns = data_columns + CDC_COLUMNS
    placeholders = ", ".join(["?"] * len(all_columns))
    insert_sql = f"""
        INSERT INTO {changes_table} ({quote_columns(all_columns)}, _loaded_at)
        VALUES ({placeholders}, current_timestamp)
    """
    for change in changes:
        values = []
        for column in all_columns:
            values.append(change[column])
        con.execute(insert_sql, values)


def apply_change(con, table_name, change, data_columns):
    """Apply one change to raw. Returns False if the key does not exist (U, D)."""
    key_column = TABLE_KEYS[table_name]
    key = change[key_column]
    op_type = change["op_type"]
    raw_table = f"raw.{table_name}"

    data_values = []
    for column in data_columns:
        data_values.append(change[column])

    if op_type == "I":
        # Delete first, so a re-run does not create a duplicate key
        con.execute(f"DELETE FROM {raw_table} WHERE {key_column} = ?", [key])
        placeholders = ", ".join(["?"] * len(data_columns))
        insert_sql = f"""
            INSERT INTO {raw_table} ({quote_columns(data_columns)}, updated_at, _loaded_at)
            VALUES ({placeholders}, ?, current_timestamp)
        """
        con.execute(insert_sql, data_values + [change["change_ts"]])
        return True

    if op_type == "U":
        set_parts = []
        for column in data_columns:
            set_parts.append(f'"{column}" = ?')
        set_parts.append("updated_at = ?")
        set_parts.append("_loaded_at = current_timestamp")
        update_sql = f"UPDATE {raw_table} SET {', '.join(set_parts)} WHERE {key_column} = ?"
        values = data_values + [change["change_ts"], key]
        updated_rows = con.execute(update_sql, values).fetchone()[0]
        return updated_rows > 0

    if op_type == "D":
        delete_sql = f"DELETE FROM {raw_table} WHERE {key_column} = ?"
        deleted_rows = con.execute(delete_sql, [key]).fetchone()[0]
        return deleted_rows > 0

    raise ValueError(f"Unknown op_type: {op_type}")


def main():
    batch_id = int(sys.argv[1])
    con = duckdb.connect(DB_PATH)

    print(f"=== Apply batch {batch_id} ===")
    for table_name in TABLE_KEYS:
        changes = read_batch(table_name, batch_id)
        data_columns = get_data_columns(changes[0])
        ordered_changes = sorted(changes, key=get_change_ts)

        # One transaction per table: the batch is applied fully or not at all
        con.begin()
        append_to_change_log(con, table_name, batch_id, ordered_changes, data_columns)

        counts = {"I": 0, "U": 0, "D": 0, "skipped": 0}
        for change in ordered_changes:
            applied = apply_change(con, table_name, change, data_columns)
            if applied:
                counts[change["op_type"]] += 1
            else:
                counts["skipped"] += 1
                print(f"Skipped {change['op_type']} on missing key: {change[TABLE_KEYS[table_name]]}")
        con.commit()

        print(f"{table_name}: {len(changes)} changes -> {counts}")

    con.close()


if __name__ == "__main__":
    main()
