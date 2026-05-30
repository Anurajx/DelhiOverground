import sqlite3
import os

db_path = r"assets/routes.db"

if not os.path.exists(db_path):
    print("Database does not exist at:", db_path)
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Check if dbstat table is available
try:
    cursor.execute("SELECT name, sum(pgsize) FROM dbstat GROUP BY name")
    results = cursor.fetchall()
    print("Physical Table Sizes (including indexes / internal pages via dbstat):")
    total = 0
    for name, size in results:
        print(f"  {name}: {size / 1024 / 1024:.2f} MB ({size:,} bytes)")
        total += size
    print(f"Total calculated size: {total / 1024 / 1024:.2f} MB")
except Exception as e:
    print("dbstat virtual table is not available, falling back to schema size estimation.")
    # Alternate method: count bytes of values in each row
    tables = ['stops', 'routes', 'trips', 'stop_times']
    for table in tables:
        # Get column names
        cursor.execute(f"PRAGMA table_info({table})")
        cols = [col[1] for col in cursor.fetchall()]
        
        # Build sum of length query
        length_expressions = []
        for col in cols:
            length_expressions.append(f"IFNULL(length(cast([{col}] as blob)), 0)")
        
        sum_query = f"SELECT sum({' + '.join(length_expressions)}) FROM [{table}]"
        try:
            cursor.execute(sum_query)
            data_size = cursor.fetchone()[0] or 0
            print(f"Estimated raw data size for '{table}' (values only): {data_size / 1024 / 1024:.2f} MB ({data_size:,} bytes)")
        except Exception as query_err:
            print(f"Error measuring table {table}: {query_err}")

conn.close()
