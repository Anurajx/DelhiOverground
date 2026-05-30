import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("SELECT trip_id, route_id, trip_headsign, direction_id FROM trips LIMIT 20")
rows = c.fetchall()
for r in rows:
    print(r)
conn.close()
