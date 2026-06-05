import sqlite3

def main():
    conn = sqlite3.connect('assets/routes.db')
    cursor = conn.cursor()
    
    # 1. Search routes table for OUTERMUDRIKA
    print("=== ROUTES matching OUTERMUDRIKA ===")
    cursor.execute("SELECT route_id, route_long_name, agency_id, start_stop, end_stop FROM routes WHERE route_long_name LIKE '%OUTERMUDRIKA%'")
    routes = cursor.fetchall()
    for r in routes:
        print(r)
        
    if not routes:
        print("No routes found matching 'OUTERMUDRIKA'")
        # Let's search for MUDRIKA generally to see what exists
        cursor.execute("SELECT route_id, route_long_name FROM routes WHERE route_long_name LIKE '%MUDRIKA%' LIMIT 10")
        print("\n=== Sample MUDRIKA routes ===")
        for r in cursor.fetchall():
            print(r)
        return
        
    route_ids = [r[0] for r in routes]
    
    # 2. Check stops table for any stops containing these route IDs in routes_list
    print("\n=== STOPS associated with these routes ===")
    for rid in route_ids:
        cursor.execute("SELECT stop_id, stop_name, routes_list FROM stops WHERE routes_list LIKE ?", (f"%{rid}#%",))
        stops = cursor.fetchall()
        print(f"Route ID {rid}: found {len(stops)} stops in stops table")
        if len(stops) > 0:
            print("Sample stops:")
            for s in stops[:5]:
                print(s)
                
    conn.close()

if __name__ == '__main__':
    main()
