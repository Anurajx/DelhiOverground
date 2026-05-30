import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("""
    SELECT route_id, route_long_name, agency_id
    FROM routes
    WHERE route_long_name NOT LIKE '%UP%' AND route_long_name NOT LIKE '%DOWN%'
    LIMIT 20
""")
rows = c.fetchall()
print("Routes without UP or DOWN in name:")
for r in rows:
    print(r)
conn.close()
