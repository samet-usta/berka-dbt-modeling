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

con = duckdb.connect(DB_PATH)
con.execute("CREATE SCHEMA IF NOT EXISTS raw")

for file_name, table_name in TABLES.items():
    csv_path = f"{RAW_DIR}/{file_name}.csv"

    # all_varchar: types are cast later in staging
    sql = f"""
        CREATE OR REPLACE TABLE raw.{table_name} AS
        SELECT *, current_timestamp AS _loaded_at
        FROM read_csv('{csv_path}', delim=';', header=true, all_varchar=true)
    """
    con.execute(sql)

    row_count = con.execute(f"SELECT COUNT(*) FROM raw.{table_name}").fetchone()[0]
    print(f"raw.{table_name}: {row_count} rows")

con.close()
