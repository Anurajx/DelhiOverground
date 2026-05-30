import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("SELECT stop_id, stop_name, routes_list FROM stops WHERE routes_list IS NOT NULL AND routes_list != '' LIMIT 20")
rows = c.fetchall()
for r in rows:
    print(r)
conn.close()
