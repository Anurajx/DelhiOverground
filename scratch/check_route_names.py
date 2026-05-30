import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("SELECT route_id, route_long_name, agency_id FROM routes LIMIT 20")
rows = c.fetchall()
print("Sample routes:")
for r in rows:
    print(r)

c.execute("SELECT COUNT(*) FROM routes WHERE route_long_name LIKE '%UP%' OR route_long_name LIKE '%DOWN%'")
has_up_down = c.fetchone()[0]
print("\nRoutes with UP or DOWN in their name:", has_up_down)
conn.close()
