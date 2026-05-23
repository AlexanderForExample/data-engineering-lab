-- E1
select oi.order_id, oi.product_id, p.product_name, oi.price, p.price, oi.price  - p.price as difference
from order_items as oi
inner join products as p 
on oi.product_id = p.product_id 
and oi.price  != p.price

-- E2
select order_id, count(*) as cnt, SUM(quantity) as total_quantity
from order_items
group by order_id 
having SUM(quantity) > 5

-- E3
select p.product_id, p.product_name, p.price, MAX(oi.price) as max_price, MAX(oi.price ) - p.price as difference
from products as p
inner join order_items as oi
on oi.product_id = p.product_id 
group by p.product_id, p.product_name, p.price
HAVING MAX(oi.price) > p.price

-- E4
SELECT u.user_id, u.email, u.registered_at, o.order_id, o.order_date 
FROM users AS u
INNER JOIN orders AS o
    ON u.user_id = o.user_id 
WHERE o.order_date < u.registered_at

-- E5
select oi.order_id, MAX(p.category), COUNT(distinct oi.product_id) as unique_products, SUM(oi.price) as total_price
from order_items as oi
inner join products as p
on oi.product_id = p.product_id 
GROUP BY oi.order_id
HAVING COUNT(DISTINCT p.category) = 1;

-- M1
with cte as (
select order_id, SUM(quantity * price) as total, MAX(quantity * price) as most_expensive
from order_items
group by order_id
)
select *, ROUND((most_expensive * 100.0 / total), 2) AS share_pct
from cte

-- M2
-- не особо получается

-- M3
WITH order_stats AS (
    SELECT 
        oi.order_id,
        COUNT(DISTINCT p.category) as categories_in_order
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status = 'paid'
    GROUP BY oi.order_id
)
SELECT 
    p.category,
    COUNT(DISTINCT CASE WHEN os.categories_in_order > 1 THEN os.order_id END) AS orders_with_other,
    COUNT(DISTINCT os.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN os.categories_in_order > 1 THEN os.order_id END) * 1.0 / COUNT(DISTINCT os.order_id) AS share
FROM products AS p
JOIN order_items AS oi ON p.product_id = oi.product_id
JOIN order_stats AS os ON oi.order_id = os.order_id
GROUP BY p.category

-- H1
with cte as (
	select u.user_id, u.email, p.category,
		   SUM(oi.price * oi.quantity) as category_revenue
	from users as u
	join orders as o 
		on u.user_id = o.user_id 
	join order_items as oi
		on o.order_id = oi.order_id 
	join products as p
		on oi.product_id = p.product_id 
	where o.status = 'paid'
	group by u.user_id, u.email, p.category 
),
cte_2 as (
	select *,
		   SUM(category_revenue) OVER (PARTITION BY user_id) as total_user_revenue,
		   dense_rank() over (partition by user_id order by category_revenue DESC) as rnk
	from cte
)
select user_id, 
       email, 
       category, 
       category_revenue, 
       total_user_revenue,
    category_revenue / total_user_revenue as share
from cte_2
where rnk = 1


-- H2
with cte as (
    select 
        o.user_id, 
        o.order_id, 
        o.order_date,
        sum(oi.price * oi.quantity) as current_order_amount
    from orders o
    join order_items oi on o.order_id = oi.order_id
    where o.status = 'paid'
    group by o.user_id, o.order_id, o.order_date
),
cte2 as (
select 
    *,
    lag(current_order_amount) over (partition by user_id order by order_date) as prev_order_amount
from cte
)
select current_order_amount,  
       prev_order_amount,
       ABS(current_order_amount - prev_order_amount) as diff,
       ((current_order_amount - prev_order_amount) * 100.0 / prev_order_amount)  as percent_diff
from cte2 
where prev_order_amount is not null 
  and abs((current_order_amount - prev_order_amount) * 100.0 / prev_order_amount) > 20

-- B1
with cte as (
	select o.order_id, 
	       count(distinct p.product_name) as distinct_products, 
	       count(distinct p.category) as distinct_cat
	from orders as o
	join order_items as oi
		on o.order_id = oi.order_id
	join products as p
		on oi.product_id = p.product_id 
	where o.status = 'paid'
	group by o.order_id 
)
select *,
       (distinct_products * 1.0) / distinct_cat as index
from cte
order by index DESC
