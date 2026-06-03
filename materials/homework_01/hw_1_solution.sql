-- E1

SELECT oi.order_id, oi.product_id, p.product_name, oi.price, p.price, p.price-oi.price as current_vs_old
from lecture_01.order_items oi
join lecture_01.products p on oi.product_id = p.product_id
where oi.price != p.price

-- E2

SELECT order_id, count(product_id) as product_cnt, sum(quantity) as quantity
from lecture_01.order_items
GROUP BY order_id
order by order_id

-- E3

select p.product_id, p.product_name, p.price, max(oi.price) as max_price, max(oi.price)-p.price as diff
from lecture_01.order_items oi
join lecture_01.products p on oi.product_id = p.product_id
where oi.price > p.price
GROUP BY p.product_id

-- E4
select u.user_id, u.email, u.registered_at, o.order_id, o.order_date
from lecture_01.users u
join lecture_01.orders o on u.user_id = o.user_id
where u.registered_at > o.order_date;

-- E5
SELECT oi.order_id, ANY_VALUE(p.category) as category, 
count(p.product_name) as dif_pr_cnt, sum(oi.price*oi.quantity) as order_sum
from lecture_01.order_items oi join 
lecture_01.products p on oi.product_id = p.product_id
group by oi.order_id
having count(DISTINCT(p.category)) = 1
order by oi.order_id

-- M1 

with whole_sums as (
    select order_id, price, price*quantity as product_sum,
    ROW_NUMBER() over (partition by order_id order by price desc) as rn,
    SUM(price*quantity) over (PARTITION BY order_id) as whole_sum
    from lecture_01.order_items
    order by order_id, rn 
)

select order_id, whole_sum, product_sum, ROUND(product_sum/whole_sum*100) as part_percents
from whole_sums
where rn = 1

-- M2
with info as (
    select u.user_id, u.email, amount, 
    count(order_id) over (partition by u.user_id) as order_cnt, 
    AVG(amount) over (partition by u.user_id),
    ROW_NUMBER() over (partition by u.user_id order by order_date desc)
    from lecture_01.orders o
    join lecture_01.users u on o.user_id = u.user_id
    where o.status = 'paid'
)

select user_id, email, amount, order_cnt, avg, amount-avg as diff_am_avg
from info 
where row_number = 1

-- M3

with paid_orders as (
    select DISTINCT oi.order_id, status, p.category from lecture_01.order_items oi 
    join lecture_01.orders o on oi.order_id = o.order_id
    join lecture_01.products p on oi.product_id = p.product_id
    where status = 'paid'
),

statistics as (
    select order_id, category,
    count(order_id) over (partition by category) as ord_with_cat,
    count(category) over (partition by order_id) as cat_in_ord 
 
    from paid_orders

)

select category, sum(case when cat_in_ord > 1 then 1 else 0 end) as orders_cnt , ANY_VALUE(ord_with_cat) as ord_with_cat,
ROUND(100*sum(case when cat_in_ord > 1 then 1 else 0 end)/ANY_VALUE(ord_with_cat)) as frac_perc
from statistics
group by category

-- H1
with paid_orders as (
    select o.user_id, u.email, category, amount, 
    sum(amount) over (partition by o.user_id) as amount_sum,
    sum(amount) over (partition by o.user_id, category) as cat_sum,
    RANK() over (partition by o.user_id order by amount desc)
    from lecture_01.orders o
    join lecture_01.users u on o.user_id = u.user_id
    join lecture_01.order_items oi on o.order_id = oi.order_id
    join lecture_01.products p on oi.product_id = p.product_id
    where status = 'paid'
)

select user_id, email, category, cat_sum, amount_sum, ROUND(cat_sum/amount_sum *100) as frac_perc
from paid_orders
where rank = 1


-- H2

with change as (
    select user_id,order_date, amount,
LAG(amount) over (partition by user_id order by order_date) as prev_amount,
amount - LAG(amount) over (partition by user_id order by order_date) as curr_prev_diff,
ROUND(100*(amount - LAG(amount) over (partition by user_id order by order_date))/LAG(amount) over (partition by user_id order by order_date)) as diff_perc
from lecture_01.orders
where status = 'paid'
)

select * from change 
where ABS(diff_perc)>20

-- H3
with category_info as (
    select o.order_id, category, 
    sum(amount) over (partition by o.order_id, category) as category_sum,
    sum(amount) over (partition by o.order_id) as order_sum
    from lecture_01.orders o
    join lecture_01.order_items oi on o.order_id = oi.order_id
    join lecture_01.products p on oi.product_id = p.product_id
    where status = 'paid'
)

select order_id, category, 
order_sum, category_sum, 
ROUND(category_sum/order_sum*100) as cat_frac_perc
from category_info
where  ROUND(category_sum/order_sum*100)>80

-- H4

with cat_rangs as (
    select u.user_id, u.email, o.order_date, p.category,
ROW_NUMBER() over (partition by u.user_id, p.category order by u.user_id, order_date) as cat_app
from lecture_01.orders o
join lecture_01.order_items oi on o.order_id = oi.order_id
join lecture_01.users u on o.user_id = u.user_id
join lecture_01.products p on oi.product_id = p.product_id
)

select user_id, email, category, order_date,
ROW_NUMBER() over (partition by user_id) as cat_order
from cat_rangs
where cat_app = 1

-- H5
with order_info as (
    select o.order_id, o.user_id, o.status, o.amount,
sum(quantity*price) over (partition by o.order_id) as order_sum
from lecture_01.orders o
join lecture_01.order_items oi on o.order_id = oi.order_id
)

select order_id, user_id, status, amount, order_sum,
order_sum-amount as ord_s_am_diff, ROUND((order_sum-amount)/amount*100) as diff_perc
from order_info
where ABS(ROUND((order_sum-amount)/amount*100))>10

-- B1
SELECT 
    o.order_id,
    count(distinct p.product_id) as pr_cnt,
    count(DISTINCT p.category) as cat_cnt,
    round(count(DISTINCT p.category)*1.0/count(distinct p.product_id),1) as div_ind
FROM lecture_01.orders o
JOIN lecture_01.order_items oi ON o.order_id = oi.order_id
JOIN lecture_01.products p ON oi.product_id = p.product_id
WHERE o.status = 'paid'
GROUP BY o.order_id
order by div_ind DESC


-- B2

select u.user_id, u.email, ANY_VALUE(p.category) as category, 
count(DISTINCT o.order_id) as order_cnt,
sum(amount)
FROM lecture_01.orders o
JOIN lecture_01.order_items oi ON o.order_id = oi.order_id
JOIN lecture_01.products p ON oi.product_id = p.product_id
JOIN lecture_01.users u on u.user_id = o.user_id
WHERE o.status = 'paid'
GROUP BY u.user_id
having count(DISTINCT p.category)=1

-- B3
select p.product_id, p.product_name,
MIN(oi.price),
MAX(oi.price),
MAX(oi.price) - MIN(oi.price) as diff,
count(oi.order_id) as order_cnt
from lecture_01.order_items oi 
join lecture_01.products p on oi.product_id = p.product_id
GROUP BY p.product_id
order by product_id