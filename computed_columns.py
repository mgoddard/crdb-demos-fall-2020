#!/usr/bin/env python3

#
# Prior to running, set the two required connection parameters as environment variables:
#
#   PGDATABASE, PGUSER, PGHOST, PGPORT, PGPASSWORD
#

"""
Demo:
  1. Ingest JSON formatted data (Source: https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json)
  2. Pull fields out of it, into their own columns
  3. Lower case these extracted fields
  4. Index the lower cased versions (plus the "yr" column -- the year)
  5. Build inverted indexes on the actors_lc and genres_lc columns
  6. Leave the original JSON intact, in the "agg" column
  7. SELECT yr, agg FROM movies WHERE actors_lc @> '{"jack black"}' ORDER BY yr DESC;

"""

import psycopg2
import psycopg2.errorcodes
import logging
import sys, os
import json

"""
drop table if exists movies;
create table movies
(
  -- Normalize the cast to lower
  title_lc string
  , actors_lc string[]
  , genres_lc string[]
  , yr int
  , agg jsonb
  , family (title_lc, actors_lc, genres_lc, yr)
  , family (agg)
);

create index on movies (yr);
create index on movies (title_lc);
create index on movies using gin(actors_lc);
create index on movies using gin(genres_lc);

"""

sql = "INSERT INTO movies (title_lc, actors_lc, genres_lc, yr, agg) VALUES (%s, %s, %s, %s, %s::JSON)"

if len(sys.argv) < 2:
  print("Usage: %s movies.json" % sys.argv[0])
  sys.exit(1)
movie_file = sys.argv[1]

conn = psycopg2.connect(database=os.getenv("PGDATABASE", "defaultdb"), user=os.getenv("PGUSER", "root"), password=os.getenv("PGPASSWORD", ""))
movie_file = sys.argv[1]

max_rows = 1000000
n = 0
with open(movie_file) as js:
  m = json.load(js)
  for row in m:
    if n >= max_rows:
      break
    print(json.dumps(row))
    # {"title": "Destroyer", "year": 2018, "cast": ["Nicole Kidman", "Tatiana Maslany", "Sebastian Stan"], "genres": ["Crime", "Thriller"]}
    title_lc = row["title"].lower()
    actors_lc = []
    for actor in row["cast"]:
      actors_lc.append(actor.lower())
    genres_lc = []
    for genre in row["genres"]:
      genres_lc.append(genre.lower())
    with conn.cursor() as cur:
      cur.execute(sql, (title_lc, actors_lc, genres_lc, int(row["year"]), json.dumps(row)))
      conn.commit()
    n += 1
conn.close()

