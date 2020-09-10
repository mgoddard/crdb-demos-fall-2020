-- Start a data load (skipping the first 110k lines of input):
-- ./load_osm_no_gis.py ~/GIS/Open_Street_Map/osm_10m_eu.txt.gz 1000000 1100000

-- This query can be run with just a few rows
SELECT name, geohash4, id, date_time
FROM osm
-- AS OF SYSTEM TIME experimental_follower_read_timestamp()
ORDER BY geohash4, id
LIMIT 10;

-- This one is more interesting, but requires more data
SELECT name, geohash4, id, date_time, key_value
FROM osm
-- AS OF SYSTEM TIME experimental_follower_read_timestamp()
WHERE key_value @> ARRAY['gcpv', 'amenity=pub', 'real_ale=yes']
ORDER BY geohash4, id
LIMIT 10;

