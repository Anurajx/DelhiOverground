import sqlite3

db_path = "assets/routes.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Check duplicates of route_long_name within same agency
duplicates_within_agency = cursor.execute("""
    SELECT route_long_name, agency_id, count(*), group_concat(route_id)
    FROM routes
    GROUP BY route_long_name, agency_id
    HAVING count(*) > 1
    LIMIT 10
""").fetchall()

print("Duplicates of route_long_name within the same agency:")
for row in duplicates_within_agency:
    print(row)

# Total unique (route_long_name, agency_id) pairs
unique_pairs = cursor.execute("""
    SELECT count(*) FROM (
        SELECT distinct route_long_name, agency_id FROM routes
    )
""").fetchone()[0]
print("Total unique (route_long_name, agency_id) pairs:", unique_pairs)

conn.close()
