import sqlite3

def test_details():
    conn = sqlite3.connect('assets/routes.db')
    cursor = conn.cursor()
    
    route_id = '142'
    print(f"Details for route_id: {route_id}")
    
    # Let's count trips
    trips = cursor.execute("SELECT trip_id, direction_id FROM trips WHERE route_id = ?", (route_id,)).fetchall()
    print(f"Total trips for route: {len(trips)}")
    
    # Let's see some stop times and arrival times
    trip_id = trips[0][0]
    print(f"Trip ID: {trip_id}")
    stop_times = cursor.execute("""
        SELECT st.stop_sequence, st.arrival_time, st.departure_time, s.stop_name
        FROM stop_times st
        JOIN stops s ON st.stop_id = s.stop_id
        WHERE st.trip_id = ?
        ORDER BY st.stop_sequence ASC
    """, (trip_id,)).fetchall()
    
    print(f"Stops ({len(stop_times)}):")
    for st in stop_times[:3]:
        print(f"  Seq {st[0]}: {st[3]} (Arr: {st[1]}, Dep: {st[2]})")
    print("  ...")
    for st in stop_times[-3:]:
        print(f"  Seq {st[0]}: {st[3]} (Arr: {st[1]}, Dep: {st[2]})")
        
    # Let's see if we can get the first and last bus timings for this route
    # First trip start time and last trip start time
    trip_start_times = []
    for (t_id, _) in trips:
        first_stop = cursor.execute("""
            SELECT arrival_time 
            FROM stop_times 
            WHERE trip_id = ? 
            ORDER BY stop_sequence ASC 
            LIMIT 1
        """, (t_id,)).fetchone()
        if first_stop and first_stop[0]:
            trip_start_times.append(first_stop[0])
            
    if trip_start_times:
        trip_start_times.sort()
        print(f"First bus departure: {trip_start_times[0]}")
        print(f"Last bus departure: {trip_start_times[-1]}")
        
    conn.close()

if __name__ == '__main__':
    test_details()
