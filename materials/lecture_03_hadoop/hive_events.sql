CREATE DATABASE IF NOT EXISTS lecture_03;
USE lecture_03;

DROP TABLE IF EXISTS events_partitioned;
DROP TABLE IF EXISTS events_raw;

CREATE EXTERNAL TABLE events_raw (
    event_id INT,
    user_id INT,
    event_type STRING,
    product_id INT,
    source STRING,
    event_ts STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/warehouse/events_raw';

CREATE EXTERNAL TABLE events_partitioned (
    event_id INT,
    user_id INT,
    event_type STRING,
    product_id INT,
    source STRING,
    event_ts STRING
)
PARTITIONED BY (event_date STRING)
STORED AS PARQUET
LOCATION '/warehouse/events_partitioned';

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

INSERT OVERWRITE TABLE events_partitioned
PARTITION (event_date)
SELECT
    event_id,
    user_id,
    event_type,
    product_id,
    source,
    event_ts,
    substr(event_ts, 1, 10) AS event_date
FROM events_raw;

SHOW TABLES;
SHOW PARTITIONS events_partitioned;

SELECT *
FROM events_raw;

SELECT
    event_date,
    count(*) AS events_count
FROM events_partitioned
GROUP BY event_date
ORDER BY event_date;

SELECT *
FROM events_partitioned
WHERE event_date = '2026-05-24';

-- Map-side join example:
-- events_raw is the main table, event_types_dict is a small dictionary.
-- Hive can load the small dictionary into mapper memory and avoid a reduce-side shuffle.
SET hive.auto.convert.join = true;
SET hive.mapjoin.smalltable.filesize = 25000000;

DROP TABLE IF EXISTS event_types_dict;

CREATE TABLE event_types_dict (
    event_type STRING,
    event_group STRING,
    event_description STRING
)
STORED AS TEXTFILE;

INSERT INTO event_types_dict VALUES
    ('view', 'interest', 'User viewed a product'),
    ('add_to_cart', 'intent', 'User added a product to cart'),
    ('purchase', 'conversion', 'User purchased a product');

-- Regular join syntax. With hive.auto.convert.join=true Hive may convert it to map-side join automatically.
SELECT
    e.event_id,
    e.user_id,
    e.event_type,
    d.event_group,
    d.event_description,
    e.product_id,
    e.source,
    e.event_ts
FROM events_raw e
JOIN event_types_dict d
    ON e.event_type = d.event_type;

-- Explicit map-side join hint. Alias d is the small table loaded into mapper memory.
SELECT
    /*+ MAPJOIN(d) */
    e.event_id,
    e.user_id,
    e.event_type,
    d.event_group,
    d.event_description,
    e.product_id,
    e.source,
    e.event_ts
FROM events_raw e
JOIN event_types_dict d
    ON e.event_type = d.event_type;
