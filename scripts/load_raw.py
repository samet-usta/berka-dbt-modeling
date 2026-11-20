"""Load Berka CSV files into the DuckDB raw schema."""
import duckdb

DB_PATH = "berka.duckdb"
RAW_DIR = "data/raw"

# file name -> table name ("order" is a SQL keyword)
TABLES = {
    "district": "district",
    "client": "client",
    "account": "account",
    "disp": "disp",
    "card": "card",
    "loan": "loan",
    "order": "orders",
    "trans": "trans",
}

# Tables with CDC changes (snapshot SCD2): they get updated_at
CDC_TABLES = ["client", "account"]

# Initial load: all rows are valid at the end of the source data
INITIAL_UPDATED_AT = "1998-12-31 00:00:00"

con = duckdb.connect(DB_PATH)
con.execute("CREATE SCHEMA IF NOT EXISTS raw")

for file_name, table_name in TABLES.items():
    csv_path = f"{RAW_DIR}/{file_name}.csv"

    extra_columns = ""
    if table_name in CDC_TABLES:
        extra_columns = f", TIMESTAMP '{INITIAL_UPDATED_AT}' AS updated_at"

    # all_varchar: types are cast later in staging
    sql = f"""
        CREATE OR REPLACE TABLE raw.{table_name} AS
        SELECT *, current_timestamp AS _loaded_at{extra_columns}
        FROM read_csv('{csv_path}', delim=';', header=true, all_varchar=true)
    """
    con.execute(sql)

    row_count = con.execute(f"SELECT COUNT(*) FROM raw.{table_name}").fetchone()[0]
    print(f"raw.{table_name}: {row_count} rows")

# A full reload starts the CDC history again
for table_name in CDC_TABLES:
    con.execute(f"DROP TABLE IF EXISTS raw.{table_name}_changes")
    print(f"raw.{table_name}_changes: dropped")

con.close()
