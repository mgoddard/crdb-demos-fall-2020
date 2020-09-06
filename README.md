# crdb-demos-fall-2020
Some demos and experiments using CockroachDB


## AS OF SYSTEM TIME ...

* Load 1M rows of the OpenStreetMap data set.
* Run this query with the `AS OF SYSTEM TIME ...` commented out (as shown):

```
WITH q3 AS
(
  SELECT name,
    ST_Distance(ST_MakePoint(-0.1192033, 51.5172348)::GEOGRAPHY, ref_point::GEOGRAPHY)::NUMERIC(9, 2) dist_m,
    ST_AsText(ref_point), date_time, uid, key_value
  FROM osm
  WHERE
    key_value @> '{gcpv, amenity=pub, real_ale=yes}'
)
SELECT * FROM q3
-- AS OF SYSTEM TIME experimental_follower_read_timestamp()
-- AS OF SYSTEM TIME '-180s'
WHERE dist_m < 2.0E+03
ORDER BY dist_m ASC
LIMIT 10;
```

* Uncomment the `AS OF SYSTEM TIME ...` line and re-run, observing the effect on runtime.

## Moving / exchanging partitions – data archivization

* Interpreting this as how to efficiently delete older data 
* [Related GitHub issue](https://github.com/cockroachdb/docs/issues/5647)
* Example, using the same OSM data set, loaded in batches for the above:

* Get a sample of the MVCC timestamps:
```
SELECT name, crdb_internal_mvcc_timestamp, (crdb_internal_mvcc_timestamp/1.0E+09)::INT::TIMESTAMP
FROM osm
ORDER BY RANDOM()
LIMIT 10;
```

* Delete a batch of 10k rows:
```
DELETE FROM osm -- Takes ~ 30 s
WHERE crdb_internal_mvcc_timestamp < '2020-09-06 02:00:00'::TIMESTAMP::INT*1.0E+09
LIMIT 10000;
```


