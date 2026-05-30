import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("""
    SELECT t.route_id, r.route_long_name, COUNT(DISTINCT t.direction_id) as dir_count
    FROM trips t
    JOIN routes r ON t.route_id = r.route_id
    GROUP BY t.route_id
    HAVING dir_count > 1
    LIMIT 10
""")
rows = c.fetchall()
print("Routes with more than one direction_id:")
for r in rows:
    print(r)
conn.close()
