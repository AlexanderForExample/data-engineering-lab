E1

select o.order_id, o.product_id, p.product_name, o.price, p.price, abs(o.price - p.price) as Difference
from order_items_p as o
left join products_p as p on o.product_id = p.product_id
where abs(o.price - p.price) != 0

E2

select order_id, count(product_id) as cnt_items, sum(quantity) as cnt_quantity
from order_items_p
group by order_id
having sum(quantity) > 5

E3

select o.product_id, p.product_name, p.price, max(o.price), max(o.price) - p.price
from order_items_p as o
left join products_p as p on o.product_id = p.product_id
where o.price > p.price
group by o.product_id, p.product_name, p.price

E4

select u.user_id, u.email, u.registered_at, o.order_id, o.order_date
from orders_p as o
left join users_p as u on o.user_id  = u.user_id
where o.order_date < u.registered_at

E5

select o.order_id, max(p.category) as category, count(distinct o.product_id), sum(o.price * o.quantity) as total
from order_items_p as o
left join products_p as p on o.product_id  = p.product_id
group by o.order_id
having count(distinct p.category) = 1

M1

select o.order_id, sum(o.price * o.quantity) as total_sum, max(o.price) as most_expensive, max(o.price * o.quantity) / sum(o.price * o.quantity) * 100 as fraction
from order_items_p as o
group by o.order_id
order by o.order_id 

M2

--with min_two_orders as (
--select o.user_id, avg(amount) 
--from orders_p as o
--where o.status = 'paid'
--group by o.user_id
--having count(order_id) > 1),
--
--last_order as (
--select user_id, max(order_date) as last_date
--from orders_p
--where status = 'paid'
--group by user_id
--)
--
--sum_last_order as (
--select o.user_id, o.amount
--from orders_p as o
--left join last_order as l on o.user_id = l.user_id
--where status = 'paid' and o.order_date = l.last_date
--group by user_id
--)

M3

with order_category_count as (
    select oip.order_id, count(distinct pp.category) as distinct_cat_in_order
    from order_items_p oip
    join products_p pp on oip.product_id = pp.product_id
    join orders_p op on oip.order_id = op.order_id
    where op.status = 'paid'
    group by oip.order_id
),

category_orders as (
    select distinct pp.category, oip.order_id
    from order_items_p oip
    join products_p pp on oip.product_id = pp.product_id
    join orders_p op on oip.order_id = op.order_id
    where op.status = 'paid'
)

select co.category, sum(case when occ.distinct_cat_in_order >= 2 then 1 else 0 end) as orders_with_other,
count(distinct co.order_id) as total_orders, 
round(sum(case when occ.distinct_cat_in_order >= 2 then 1 else 0 end) * 1.0 / count(distinct co.order_id), 2) as share
from category_orders co
join order_category_count occ on co.order_id = occ.order_id
group by co.category
order by co.category;


H1

with helper as (
select op.user_id, pp.category, sum(op.amount) as total_category_sum,
rank() over (partition by op.user_id order by sum(op.amount) desc) as rank_of_category,
sum(sum(op.amount)) over (partition by op.user_id) as user_total_sum
from order_items_p oip
join products_p pp on oip.product_id = pp.product_id
join orders_p op on oip.order_id = op.order_id
where op.status = 'paid'
group by op.user_id, pp.category
)
select h.user_id, up.email, h.category, h.total_category_sum, h.user_total_sum, h.total_category_sum / h.user_total_sum as share
from helper h
left join users_p up on h.user_id = up.user_id
where h.rank_of_category = 1

H2

with helper1 as (
select op.user_id, op.order_id, op.amount, op.order_date, rank() over (partition by op.user_id order by op.order_date) as rank
from orders_p op
where op.status = 'paid'
order by op.user_id, op.order_date
),
helper2 as (
select h1.user_id, h1.order_id, h1.rank, h1.amount as current_amount,
lag(h1.amount) over (partition by h1.user_id order by h1.order_date) as previous_amount
from helper1 h1
where h1.user_id in (select helper1.user_id from helper1 group by helper1.user_id having count(*) > 1)
)
select h2.user_id, h2.order_id, h2.current_amount, h2.previous_amount, 
abs(h2.current_amount - h2.previous_amount) as difference, 
round(abs(h2.current_amount - h2.previous_amount) / h2.previous_amount * 100) as share
from helper2 as h2
where h2.previous_amount is not null and 
round(abs(h2.current_amount - h2.previous_amount) / h2.previous_amount * 100) > 20


H3

with helper1 as (
select oip.order_id, oip.product_id, pp.category, (oip.quantity * oip.price) as summ,
sum(oip.quantity * oip.price) over (partition by oip.order_id) total_sum,
(oip.quantity * oip.price) / sum(oip.quantity * oip.price) over (partition by oip.order_id) * 100 as shares
from order_items_p oip
join products_p pp on oip.product_id = pp.product_id
join orders_p op on oip.order_id = op.order_id
where op.status = 'paid'
order by oip.order_id
)
select h1.order_id, h1.category, h1.total_sum, h1.summ, h1.shares
from helper1 as h1
where h1.shares > 80

H4



H5
with helper1 as (
select oip.order_id, sum(oip.price * oip.quantity) as summ
from order_items_p as oip
group by oip.order_id
order by oip.order_id
), 
helper2 as (
select h1.order_id, op.user_id, op.status, op.amount, h1.summ, 
abs(h1.summ - op.amount) as difference, 
abs(h1.summ - op.amount) / op.amount * 100 as shares
from helper1 as h1
inner join orders_p as op on h1.order_id = op.order_id
)
select *
from helper2
where helper2.shares > 10



