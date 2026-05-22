import sqlite3

def check_agencies():
    conn = sqlite3.connect('assets/routes.db')
    cursor = conn.cursor()
    
    # Check agency_id counts in routes
    print("Agency counts in routes table:")
    agencies = cursor.execute("""
        SELECT agency_id, COUNT(*) 
        FROM routes 
        GROUP BY agency_id
    """).fetchall()
    for ag in agencies:
        print(f"  Agency: {ag[0]}, Count: {ag[1]}")
        
    # Check total distinct route names
    print("\nTotal distinct route_long_name count:")
    print(cursor.execute("SELECT COUNT(DISTINCT route_long_name) FROM routes").fetchone()[0])
    
    # Check some sample route names from different agencies
    print("\nSample routes per agency:")
    for agency_id, _ in agencies:
        print(f"\nAgency {agency_id}:")
        samples = cursor.execute("""
            SELECT route_id, route_long_name 
            FROM routes 
            WHERE agency_id = ? 
            LIMIT 5
        """, (agency_id,)).fetchall()
        for s in samples:
            print(f"  Route: {s}")
            
    conn.close()

if __name__ == '__main__':
    check_agencies()
