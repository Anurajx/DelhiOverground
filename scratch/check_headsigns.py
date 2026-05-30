import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()
c.execute("SELECT COUNT(*) FROM trips WHERE trip_headsign IS NOT NULL AND trip_headsign != ''")
non_empty = c.fetchone()[0]
print("Trips with non-empty headsigns:", non_empty)
conn.close()
