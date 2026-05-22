import sqlite3

def test_direction_query():
    conn = sqlite3.connect('assets/routes.db')
    cursor = conn.cursor()
    
    # Let's pick a route, say '828AUP' or route_id '142'
    route_id = '142'
    print(f"Checking directions for route_id: {route_id}")
    
    # Group trips by direction_id
    directions = cursor.execute("""
        SELECT DISTINCT direction_id 
        FROM trips 
        WHERE route_id = ?
    """, (route_id,)).fetchall()
    print("Directions found:", directions)
    
    for (dir_id,) in directions:
        # Get a representative trip for this direction
        # Let's find a trip that has the most stops (to be safe and get the full sequence)
        representative_trip = cursor.execute("""
            SELECT t.trip_id, COUNT(st.stop_id) as stop_count
            FROM trips t
            JOIN stop_times st ON t.trip_id = st.trip_id
            WHERE t.route_id = ? AND t.direction_id = ?
            GROUP BY t.trip_id
            ORDER BY stop_count DESC
            LIMIT 1
        """, (route_id, dir_id)).fetchone()
        
        if representative_trip:
            trip_id, stop_count = representative_trip
            print(f"  Direction {dir_id}: Representative Trip ID: {trip_id} with {stop_count} stops")
            
            # Get start stop
            start_stop = cursor.execute("""
                SELECT s.stop_name 
                FROM stop_times st
                JOIN stops s ON st.stop_id = s.stop_id
                WHERE st.trip_id = ?
                ORDER BY st.stop_sequence ASC
                LIMIT 1
            """, (trip_id,)).fetchone()
            
            # Get end stop
            end_stop = cursor.execute("""
                SELECT s.stop_name 
                FROM stop_times st
                JOIN stops s ON st.stop_id = s.stop_id
                WHERE st.trip_id = ?
                ORDER BY st.stop_sequence DESC
                LIMIT 1
            """, (trip_id,)).fetchone()
            
            print(f"    Start Stop: {start_stop[0] if start_stop else 'None'}")
            print(f"    End Stop: {end_stop[0] if end_stop else 'None'}")
        else:
            print(f"  Direction {dir_id}: No trips with stops found.")
            
    conn.close()

if __name__ == '__main__':
    test_direction_query()
