create schema if not exists stg;

create schema if not exists core;

create table core.users (
	user_id BIGSERIAL primary key,
	user_external_id TEXT unique not null,
	user_name TEXT not null,
	user_email text not null,
	user_city TEXT
);

insert into core.users (
	user_external_id,
	user_name,
	user_email,
	user_city
)
select distinct
	user_external_id,
	user_name,
	user_email,
	user_city
from stg.raw_orders_flat
on conflict (user_external_id) do nothing;
CREATE TABLE core.products (
    product_id BIGSERIAL PRIMARY KEY,
    product_sku TEXT UNIQUE NOT NULL,
    product_name TEXT NOT NULL,
    product_category TEXT NOT NULL,
    product_brand TEXT
);
CREATE TABLE core.orders (
    order_id BIGSERIAL PRIMARY KEY,
    source_order_id BIGINT UNIQUE NOT NULL,
    user_id BIGINT NOT NULL REFERENCES core.users(user_id),
    order_status TEXT NOT NULL,
    order_created_at TIMESTAMP NOT NULL
);
CREATE TABLE core.order_items (
    order_item_id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES core.orders(order_id),
    product_id BIGINT NOT NULL REFERENCES core.products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    line_amount NUMERIC(12, 2) NOT NULL CHECK (line_amount >= 0)
);


INSERT INTO core.products (
    product_sku,
    product_name,
    product_category,
    product_brand
)
SELECT DISTINCT
    product_sku,
    product_name,
    product_category,
    product_brand
FROM stg.raw_orders_flat
ON CONFLICT (product_sku) DO NOTHING;

INSERT INTO core.orders (
    source_order_id,
    user_id,
    order_status,
    order_created_at
)
SELECT DISTINCT
    f.source_order_id,
    u.user_id,
    f.order_status,
    f.order_created_at::timestamp
FROM stg.raw_orders_flat f
JOIN core.users u
    ON u.user_external_id = f.user_external_id
ON CONFLICT (source_order_id) DO NOTHING;

INSERT INTO core.order_items (
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    line_amount
)
SELECT
    o.order_id,
    p.product_id,
    f.item_quantity,
    f.item_price,
    f.item_discount,
    f.item_quantity * f.item_price - f.item_discount AS line_amount
FROM stg.raw_orders_flat f
JOIN core.orders o
    ON o.source_order_id = f.source_order_id
JOIN core.products p
    ON p.product_sku = f.product_sku;

create or replace view core.v_paid_orders as
select
	order_id,
	source_order_id,
	user_id,
	order_created_at::date as order_dt,
	order_status
from core.orders
where order_status in ('paid', 'shipped');

create or replace view core.v_sales_lines as
select o.order_created_at::date as sales_dt,
	oi.quantity * oi.unit_price as gross_amount,
	oi.quantity * oi.unit_price - oi.discount_amount as line_amount
from core.orders o
join core.order_items oi
	on oi.order_id = o.order_id
join core.products p
	on p.product_id = oi.product_id
where o.order_status in ('paid', 'shipped');

create schema if not exists mart;

create table mart.daily_sales (
	dt DATE primary key,
	gross_amount numeric(14,2),
	line_amount numeric(14,2)
)
partition by range (dt);


create table mart.daily_sales_2026_05
partition of mart.daily_sales
for values from ('2026-05-01') to ('2026-06-01');

create table mart.daily_sales_2026_06
partition of mart.daily_sales
for values from ('2026-06-01') to ('2026-07-01');


insert into mart.daily_sales (
	dt,
	gross_amount,
	line_amount
)
select
	sales_dt,
	sum(gross_amount),
	sum(line_amount)
from core.v_sales_lines
group by sales_dt;

select tableoid::regclass as partition_name,
	   dt,
	   gross_amount
from mart.daily_sales ds

insert into mart.daily_sales
values ('2026-07-01', 2225, 333);
create table mart.daily_sales_2026_07
partition of mart.daily_sales
for values from ('2026-07-01') to ('2026-08-01');

explain
select *
from mart.daily_sales
where dt >= DATE '2026-05-01'
	and dt < DATE '2026-06-01'
  ->  Bitmap Index Scan on daily_sales_2026_05_pkey  (cost=0.00..4.21 rows=6 width=0)




