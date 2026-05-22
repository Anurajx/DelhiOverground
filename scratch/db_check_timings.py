import sqlite3

def test_timings():
    conn = sqlite3.connect('assets/routes.db')
    cursor = conn.cursor()
    
    route_id = '142'
    direction_id = 0
    
    print(f"Checking timings for route_id: {route_id}, direction_id: {direction_id}")
    
    query = """
        SELECT 
            MIN(first_st.arrival_time) as first_bus, 
            MAX(first_st.arrival_time) as last_bus, 
            COUNT(DISTINCT t.trip_id) as total_trips
        FROM trips t
        JOIN stop_times first_st ON t.trip_id = first_st.trip_id
        WHERE t.route_id = ? AND t.direction_id = ? AND first_st.stop_sequence = (
            SELECT MIN(stop_sequence) FROM stop_times WHERE trip_id = t.trip_id
        )
    """
    
    res = cursor.execute(query, (route_id, direction_id)).fetchone()
    print("Result:", res)
    conn.close()

if __name__ == '__main__':
    test_timings()
