import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("SELECT route_id, route_long_name, agency_id FROM routes WHERE route_long_name LIKE '%727%'")
rows = c.fetchall()
print("Routes matching '727' in routes table:")
for r in rows:
    print(r)
conn.close()
