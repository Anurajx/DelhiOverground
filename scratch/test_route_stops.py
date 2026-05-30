import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
route_query = "727"
c.execute("SELECT stop_id, stop_name, routes_list FROM stops WHERE routes_list LIKE ? LIMIT 15", (f"%{route_query}%",))
rows = c.fetchall()
print(f"Stops matching '{route_query}':")
for r in rows:
    print(r)
conn.close()
