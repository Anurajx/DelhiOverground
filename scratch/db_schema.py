import sqlite3
import os

db_path = r"assets/routes.db"

if not os.path.exists(db_path):
    print("Database does not exist at:", db_path)
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Get table names
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [row[0] for row in cursor.fetchall()]
print(f"Tables in database: {tables}\n")

for table in tables:
    # Get column names
    cursor.execute(f"PRAGMA table_info({table})")
    cols = [col[1] for col in cursor.fetchall()]
    
    # Get count
    cursor.execute(f"SELECT COUNT(*) FROM {table}")
    count = cursor.fetchone()[0]
    
    print(f"Table: {table}")
    print(f"  Columns: {cols}")
    print(f"  Row Count: {count}")
    print("-" * 40)

conn.close()
