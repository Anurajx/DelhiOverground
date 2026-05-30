import sqlite3
import os
import time
import shutil

db_path = r"assets/routes.db"

# Restore original database first to get the complete data
print("Restoring original routes.db from build intermediates...")
src_path = r"build\app\intermediates\assets\release\mergeReleaseAssets\flutter_assets\assets\routes.db"
if not os.path.exists(src_path):
    print("Error: Source database does not exist at:", src_path)
    exit(1)

shutil.copy2(src_path, db_path)
print(f"Restored DB Size: {os.path.getsize(db_path) / 1024 / 1024:.2f} MB")

start_time = time.time()
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Step 1: Alter routes table to add start_stop and end_stop columns
print("Altering routes table to add start_stop and end_stop...")
try:
    cursor.execute("ALTER TABLE routes ADD COLUMN start_stop TEXT")
    cursor.execute("ALTER TABLE routes ADD COLUMN end_stop TEXT")
    conn.commit()
except Exception as e:
    print("Columns may already exist:", e)

# Step 2: Find the representative trip (the trip with the maximum stops) for each route
print("Finding representative trips for all routes...")
cursor.execute("""
    SELECT t.route_id, t.trip_id, COUNT(st.stop_id) as stop_count
    FROM trips t
    JOIN stop_times st ON t.trip_id = st.trip_id
    GROUP BY t.trip_id
""")
trips_data = cursor.fetchall()

# Group by route_id to find the trip_id with the max stop_count
route_rep_trips = {}
for route_id, trip_id, stop_count in trips_data:
    if route_id not in route_rep_trips or stop_count > route_rep_trips[route_id][1]:
        route_rep_trips[route_id] = (trip_id, stop_count)

print(f"Found representative trips for {len(route_rep_trips)} routes.")

# Step 3: Fetch all stop sequences for these representative trips
print("Fetching stop sequences for representative trips...")
rep_trip_ids = [trip_id for trip_id, _ in route_rep_trips.values()]

# We chunk the query to avoid SQL parameter limit
chunk_size = 900
stop_sequences = {} # stop_id -> list of (route_id, route_long_name, stop_sequence)
route_stops = {} # route_id -> list of (stop_sequence, stop_name)

# Get route_id -> route_long_name map
cursor.execute("SELECT route_id, route_long_name FROM routes")
route_map = {row[0]: row[1] for row in cursor.fetchall()}

# Get stop_id -> stop_name map
cursor.execute("SELECT stop_id, stop_name FROM stops")
stop_name_map = {row[0]: row[1] for row in cursor.fetchall()}

for i in range(0, len(rep_trip_ids), chunk_size):
    chunk = rep_trip_ids[i:i+chunk_size]
    placeholders = ",".join(["?"] * len(chunk))
    cursor.execute(f"""
        SELECT st.stop_id, t.route_id, st.stop_sequence
        FROM stop_times st
        JOIN trips t ON st.trip_id = t.trip_id
        WHERE st.trip_id IN ({placeholders})
    """, chunk)
    
    for stop_id, route_id, stop_sequence in cursor.fetchall():
        route_long_name = route_map.get(route_id)
        if route_long_name:
            if stop_id not in stop_sequences:
                stop_sequences[stop_id] = []
            stop_sequences[stop_id].append((route_id, route_long_name, stop_sequence))
            
            if route_id not in route_stops:
                route_stops[route_id] = []
            stop_name = stop_name_map.get(stop_id, "Unknown Stop")
            route_stops[route_id].append((stop_sequence, stop_name))

print(f"Processed sequences for {len(stop_sequences)} stops.")

# Step 4: Update routes table with start and end stops
print("Updating routes table with start and end stop names...")
cursor.execute("BEGIN TRANSACTION")
routes_updated = 0
for route_id, stops_list in route_stops.items():
    if stops_list:
        # Sort by stop_sequence
        stops_list.sort(key=lambda x: x[0])
        start_stop = stops_list[0][1]
        end_stop = stops_list[-1][1]
        cursor.execute("""
            UPDATE routes
            SET start_stop = ?, end_stop = ?
            WHERE route_id = ?
        """, (start_stop, end_stop, route_id))
        routes_updated += 1

cursor.execute("COMMIT")
print(f"Updated {routes_updated} route destinations.")

# Step 5: Compile routes_list for each stop and update the stops table
print("Updating stops table with ID-and-Name sequence-aware routes_list...")
cursor.execute("BEGIN TRANSACTION")

updated_count = 0
for stop_id, r_list in stop_sequences.items():
    r_list.sort(key=lambda x: x[0])
    routes_list_str = "-".join([f"{rid}#{name}:{seq}" for rid, name, seq in r_list])
    
    cursor.execute("""
        UPDATE stops
        SET routes_list = ?
        WHERE stop_id = ?
    """, (routes_list_str, stop_id))
    updated_count += 1

cursor.execute("COMMIT")
print(f"Successfully updated routes_list for {updated_count} stops.")

# Step 6: Drop stop_times table and vacuum
print("\nDropping 'stop_times' table to free space...")
cursor.execute("DROP TABLE IF EXISTS stop_times")
conn.commit()

print("Vacuuming database...")
cursor.execute("VACUUM")
conn.commit()

# Print some samples from routes table to verify
cursor.execute("SELECT route_id, route_long_name, start_stop, end_stop FROM routes WHERE end_stop IS NOT NULL LIMIT 5")
print("\nSample updated routes:")
for row in cursor.fetchall():
    print(f"ID: {row[0]}, Name: {row[1]}, From: {row[2]}, To: {row[3]}")

conn.close()

end_time = time.time()
print(f"\nCompleted in {end_time - start_time:.2f} seconds.")
print(f"Final DB Size: {os.path.getsize(db_path) / 1024 / 1024:.2f} MB")
