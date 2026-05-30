import sqlite3

conn = sqlite3.connect("assets/routes.db")
c = conn.cursor()

route_long_name = "727UP"
print(f"Testing route: '{route_long_name}'")

c.execute("""
    SELECT stop_id, stop_name, stop_lat, stop_lon, routes_list
    FROM stops
    WHERE routes_list LIKE ?
""", (f"%{route_long_name}%",))

stops_results = c.fetchall()
print(f"SQL matched {len(stops_results)} stops.")

parsed_stops = []
for row in stops_results:
    routes_list_str = row[4] or ""
    tokens = routes_list_str.split('-')
    matched = False
    for token in tokens:
        parts = token.split(':')
        if len(parts) == 2 and parts[0] == route_long_name:
            seq = int(parts[1]) if parts[1].isdigit() else 0
            parsed_stops.append({
                'stop_id': row[0],
                'stop_name': row[1],
                'sequence': seq
            })
            matched = True
            break

print(f"Successfully parsed {len(parsed_stops)} stops.")
if parsed_stops:
    parsed_stops.sort(key=lambda x: x['sequence'])
    print("Parsed stops sorted:")
    for ps in parsed_stops[:10]:
        print(ps)

conn.close()
