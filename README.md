# crdb-demos-fall-2020
Some demos and experiments using CockroachDB

## Indexing of computed columns

* DDL: table and indexes

```
CREATE TABLE movies
(
  title_lc STRING
  , actors_lc STRING[]
  , genres_lc STRING[]
  , yr INT
  , agg JSONB
  , FAMILY (title_lc, actors_lc, genres_lc, yr)
  , FAMILY (agg)
);
CREATE INDEX ON movies (yr);
CREATE INDEX ON movies (title_lc);
CREATE INDEX ON movies USING GIN(actors_lc);
CREATE INDEX ON movies USING GIN(genres_lc);
```

* [Python example](./computed_columns.py) loads/prepares data as follows:
1. Ingest JSON formatted data (Source: https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json)
1. Pull fields out of it, into their own columns
1. Lower case these extracted fields
1. Index the lower cased versions, plus the `yr` column (the year)
1. Build inverted indexes on the `actors_lc` and `genres_lc` columns
1. Store the original JSON intact, in the `agg` column (in its own column family)

* Query the data using the indexes of the computed columns; e.g.

```
SELECT yr, agg FROM movies WHERE actors_lc @> '{"jack black"}' ORDER BY yr DESC;
```

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
DELETE FROM osm -- Takes ~ 30 s for 10k and ~ 74 s for 100k (on a MacBook Pro)
WHERE crdb_internal_mvcc_timestamp < '2020-09-06 02:00:00'::TIMESTAMP::INT*1.0E+09
LIMIT 10000;
```


