--Для каждого города вывести число пользователей, дату самой ранней регистрации и дату самой поздней регистрации

select city, count(*) as users_cnt, max(registered_at) as first, min(registered_at) as last
from users
group by city
order by users_cnt desc, city

-- Для каждой категории товаров вывести количество товаров, минимальную цену, максимальную цену и среднюю цену

select
category,
count(*) as prd_cnt,
min(price) as min_price,
max(price) as max_price,
avg(price) as avg_price
from products
group by category;
-- Для каждого заказа вывести число товарных позиций и суммарное количество купленных единиц товара.

select o.order_id, o.status, count(oi.product_id), sum(oi.quantity)
from orders o
join order_items oi
	on o.order_id = oi.order_id
where o.status = 'paid'
group by o.order_id, o. status

-- Найти пользователей, у которых не меньше двух оплаченных заказов. Вывести user_id, email, число оплаченных заказов, средний чек и суммарную выручку.

select u.user_id, count(*) as paid_orders_cnt
from users u
join orders o
	on u.user_id = o.user_id
where o.status = 'paid'
group by u.user_id
having count(*) >= 2

-- Для каждого города найти самый дорогой оплаченный заказ. Вывести city, order_id, order_date, amount.
with ranked_city_orders as (
	select u.city, o.order_id, o.order_date, o.amount,
		row_number() over (partition by u.city order by o.amount desc, o.order_id) as rn
	from orders o
	join users u
		on u.user_id = o.user_id
	where o.status = 'paid'
)

select *
from ranked_city_orders
where rn = 1;

-- Для каждого пользователя показать накопительную выручку по его оплаченных заказам во времени.
with paid_orders as (
    select
        user_id,
        order_id,
        order_date,
        amount
    from orders
    where status = 'paid'
)

select user_id, order_date, order_id, amount,
		sum(amount) over (partition by user_id order by order_date) as sum_by_user
from paid_orders;

explain analyze
select count(*)
from orders
where date_trunc('day', order_date::timestamp) = timestamp '2026-01-14 00:00:00'
;

Aggregate  (cost=26.11..26.12 rows=1 width=8) (actual time=0.020..0.021 rows=1 loops=1)
  ->  Seq Scan on orders  (cost=0.00..26.10 rows=5 width=0) (actual time=0.016..0.017 rows=2 loops=1)
        Filter: (date_trunc('day'::text, (order_date)::timestamp without time zone) = '2026-01-14 00:00:00'::timestamp without time zone)
        Rows Removed by Filter: 7
Planning Time: 0.070 ms
Execution Time: 0.045 ms;

explain analyze
select
	u.user_id,
	u.email,
	(
	 select count(*)
	 from orders o
	 where o.user_id = u.user_id
	 	and o.status = 'paid'
	) as orders_cnt
from users u


Seq Scan on users u  (cost=0.00..18591.55 rows=780 width=44) (actual time=0.026..0.037 rows=6 loops=1)
  SubPlan 1
    ->  Aggregate  (cost=23.80..23.81 rows=1 width=8) (actual time=0.003..0.003 rows=1 loops=6)
          ->  Seq Scan on orders o  (cost=0.00..23.80 rows=1 width=0) (actual time=0.002..0.002 rows=1 loops=6)
                Filter: ((user_id = u.user_id) AND (status = 'paid'::text))
                Rows Removed by Filter: 8
Planning Time: 0.102 ms
Execution Time: 0.066 ms

with paid_orders_cnt as (
	 select count(*)
	 from orders o
	 where o.user_id = u.user_id
	 	and o.status = 'paid'
)

select *
from users u
join paid_orders_cnt

