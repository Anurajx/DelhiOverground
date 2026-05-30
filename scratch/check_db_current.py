import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("SELECT stop_id, stop_name, routes_list FROM stops WHERE routes_list LIKE '%727%' LIMIT 10")
for r in c.fetchall():
    print(r)
conn.close()
