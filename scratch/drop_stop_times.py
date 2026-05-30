import sqlite3
import os

db_path = r"assets/routes.db"

if not os.path.exists(db_path):
    print("Database does not exist at:", db_path)
    exit(1)

old_size = os.path.getsize(db_path)
print(f"Original DB Size: {old_size / 1024 / 1024:.2f} MB ({old_size:,} bytes)")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("Dropping 'stop_times' table...")
cursor.execute("DROP TABLE IF EXISTS stop_times")
conn.commit()

print("Vacuuming database to release unused space...")
cursor.execute("VACUUM")
conn.commit()

conn.close()

new_size = os.path.getsize(db_path)
print(f"New DB Size after dropping table and VACUUM: {new_size / 1024 / 1024:.2f} MB ({new_size:,} bytes)")
print(f"Space Saved: {(old_size - new_size) / 1024 / 1024:.2f} MB")
