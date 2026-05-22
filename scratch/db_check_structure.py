import sqlite3

def test_routes_structure():
    conn = sqlite3.connect('assets/routes.db')
    cursor = conn.cursor()
    
    print("Distinct direction_id count per route:")
    rows = cursor.execute("""
        SELECT route_id, COUNT(DISTINCT direction_id) as dir_count
        FROM trips
        GROUP BY route_id
        ORDER BY dir_count DESC
        LIMIT 10
    """).fetchall()
    for row in rows:
        print(row)
        
    print("\nCheck routes matching '828A%':")
    rows = cursor.execute("""
        SELECT route_id, route_long_name 
        FROM routes 
        WHERE route_long_name LIKE '828A%'
    """).fetchall()
    for row in rows:
        print(row)
        
    conn.close()

if __name__ == '__main__':
    test_routes_structure()
