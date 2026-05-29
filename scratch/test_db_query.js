const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '../assets/routes.db');
console.log("Opening database:", dbPath);
const db = new sqlite3.Database(dbPath, sqlite3.OPEN_READONLY, (err) => {
  if (err) {
    console.error("Failed to open DB:", err);
    process.exit(1);
  }
});

console.time("Query execution");
db.all(`
  SELECT 
    s.stop_id, 
    s.stop_name, 
    (SELECT GROUP_CONCAT(DISTINCT next_s.stop_name)
     FROM stop_times st1
     JOIN stop_times st2 ON st1.trip_id = st2.trip_id AND st2.stop_sequence = st1.stop_sequence + 1
     JOIN stops next_s ON st2.stop_id = next_s.stop_id
     WHERE st1.stop_id = s.stop_id) as next_stops
  FROM stops s
  LIMIT 200;
`, [], (err, rows) => {
  console.timeEnd("Query execution");
  if (err) {
    console.error("Query failed:", err);
  } else {
    console.log(`Successfully fetched ${rows.length} rows.`);
    console.log("Sample rows:", rows.slice(0, 5));
  }
  db.close();
});
