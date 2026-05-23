-- E1

-- В таблице `order_items` есть цена товара в момент покупки: `order_items.price`.  
-- В таблице `products` есть текущая цена товара: `products.price`.

-- Найдите строки заказов, где цена покупки отличается от текущей цены товара.

-- Выведите:

-- - `order_id`;
-- - `product_id`;
-- - `product_name`;
-- - цену из `order_items`;
-- - цену из `products`;
-- - разницу между ценами.

select order_id, p.product_id, p.product_name, oi.price, p.price 
from order_items oi 
join products p on oi.product_id = p.product_id
where oi.price != p.price 
group by order_id, p.product_id, oi.price, p.price
order by order_id asc

-- E2

-- Найдите заказы, в которых суммарно купили больше 5 единиц товаров.

-- Суммарное количество считайте как сумму `quantity` по строкам заказа.

-- Выведите:

-- - `order_id`;
-- - количество товарных позиций;
-- - суммарное количество единиц товара.

select order_id, COUNT(*) as product_positions, SUM(quantity) as total_quantity
from order_items
group by order_id
having SUM(quantity) > 5
order by order_id 


-- E3

-- Найдите товары, которые хотя бы раз были проданы дороже текущей цены из таблицы `products`.

-- Для каждого товара выведите:

-- - `product_id`;
-- - `product_name`;
-- - текущую цену;
-- - максимальную цену продажи;
-- - разницу между максимальной ценой продажи и текущей ценой.

select p.product_id, p.product_name, p.price, max(oi.price) as maxprice,  max(oi.price) - p.price as diff
from products p
join order_items oi on oi.product_id = p.product_id
group by p.product_id, p.product_name
having max(oi.price) - p.price > 0
order by p.product_id 


-- E4

-- Найдите пользователей, у которых есть заказ, созданный раньше даты регистрации пользователя.

-- Сравнивайте:

-- -`users.registered_at`;
-- - `orders.order_date`.

-- Выведите:

-- - `user_id`;
-- - `email`;
-- - дату регистрации;
-- - `order_id`;
-- - дату заказа.

select u.user_id, u.email, u.registered_at, o.order_id, o.order_date 
from users u 
join orders o on u.user_id = o.user_id
where o.order_date < u.registered_at
group by u.user_id, o.order_id


-- E5

-- Найдите заказы, в которых все товары относятся только к одной категории.

-- Выведите:

-- - `order_id`;
-- - категорию;
-- - количество разных товаров в заказе;
-- - сумму заказа по строкам `order_items`.

select oi.order_id, max(p.category) as category , count(distinct p.product_id) as cnt_products, sum(oi.price * oi.quantity) as total_sum
from order_items oi 
join products p on oi.product_id = p.product_id
group by oi.order_id 
having count(distinct p.category) = 1
order by oi.order_id 

-- M1

-- Для каждого заказа посчитайте, какую долю от суммы заказа занимает самая дорогая товарная позиция.

-- Стоимость товарной позиции считайте как:

-- ```sql
-- quantity * price
--```

-- Выведите:

-- - `order_id`;
-- - общую сумму заказа по строкам;
-- - стоимость самой дорогой позиции;
-- - долю самой дорогой позиции в процентах.


select oi.order_id, max(oi.price*oi.quantity ) as max_price, sum(oi.price * oi.quantity) as total_sum, (max(oi.price*oi.quantity )/sum(oi.price * oi.quantity)) * 100 as percent 
from order_items oi
group by oi.order_id
order by oi.order_id asc


-- M2
-- Для каждого пользователя с минимум двумя оплаченными заказами сравните:

-- - среднюю сумму его оплаченных заказов;
-- - сумму его последнего оплаченного заказа.

-- Выведите пользователей, у которых последний оплаченный заказ больше их средней суммы оплаченного заказа.

-- Выведите:

-- - `user_id`;
-- - `email`;
-- - количество оплаченных заказов;
-- - среднюю сумму оплаченного заказа;
-- - сумму последнего оплаченного заказа;
-- - разницу между последним заказом и средним.



with paid_orders as(
	select u.user_id, u.email, o.status, o.amount, o.order_date
	from users u 
	join orders o on u.user_id = o.user_id
	where status = 'paid'
	group by u.user_id, o.amount, o.status, o.order_date 
),

last_order_date as(
	select u.user_id, max(o.order_date) as last_order_date
	from users u 
	join orders o on u.user_id = o.user_id
	group by u.user_id 
	order by u.user_id 
	
	), 
	
last_order as(
	select po.user_id, po.amount, po.order_date, lod.last_order_date
	from paid_orders po
	join last_order_date lod on po.user_id = lod.user_id
	where po.order_date = lod.last_order_date
	group by po.user_id, po.email, po.amount, po.order_date, lod.last_order_date
	order by po.user_id
)

select po.user_id, po.email, count(po.status) as cnt_orders, avg(po.amount) as avg_amount, lo.amount,  lo.amount - avg(po.amount) as diff
from paid_orders po
join last_order lo on po.user_id = lo.user_id
group by po.user_id, po.email, lo.amount
having count(po.status) >= 2 and (lo.amount - avg(po.amount)) > 0


-- H1

-- Для каждого пользователя определите категорию, на которую он потратил больше всего денег в оплаченных заказах.

-- Выведите:

-- - `user_id`;
-- - `email`;
-- - категорию;
-- - выручку пользователя в этой категории;
-- - общую оплаченную выручку пользователя;
-- - долю категории в выручке пользователя.

-- Если у пользователя две категории с одинаковой максимальной выручкой, выведите обе.


with  paid_items as (
    select
        u.user_id,
        u.email,
        o.order_id,
        p.category,
        oi.quantity,
        oi.price,
        (oi.quantity * oi.price) AS item_revenue
    from orders o
    join users u 
        on u.user_id = o.user_id
    join order_items oi 
        on oi.order_id = o.order_id
    join products p 
        on p.product_id = oi.product_id
    where o.status = 'paid'
),

category_revenue as (
    select
        user_id,
        email,
        category,
        sum(item_revenue) as category_revenue
    from paid_items
    group by user_id, email, category
),

ranked_categories as (
    select
        user_id,
        email,
        category,
        category_revenue,
        sum(category_revenue) over (
            partition by user_id
        ) as total_paid_revenue,
        rank() over (
            partition by user_id
            order by category_revenue desc
        ) AS rnk
    from category_revenue
)

select
    user_id,
    email,
    category,
    category_revenue,
    total_paid_revenue,
    category_revenue / total_paid_revenue as category_share
from ranked_categories
where rnk = 1
order by user_id, category

-- H2

-- Для каждого пользователя найдите последовательность его оплаченных заказов.

-- Для каждого заказа, начиная со второго, посчитайте:

-- - сумму текущего заказа;
-- - сумму предыдущего заказа;
-- - разницу между текущим и предыдущим заказом;
-- - процент изменения относительно предыдущего заказа.

-- Выведите только те строки, где изменение по модулю больше 20%.

--- ранг по дате, условие где ранг больше или равен 2

with  paid_items_with_date as (
    select
        u.user_id,
        o.order_id,
        o.order_date,
        oi.quantity,
        oi.price,
        (oi.quantity * oi.price) AS item_revenue
    from orders o
    join users u 
        on u.user_id = o.user_id
    join order_items oi 
        on oi.order_id = o.order_id
    join products p 
        on p.product_id = oi.product_id
    where o.status = 'paid'
),


data_revenue as (
    select
        user_id,
        order_date,
        sum(item_revenue) as date_sum
    from paid_items_with_date
    group by user_id, order_date
    order by order_date asc, user_id asc
),

ranked_date as (
    select
        user_id,
        order_date,
        date_sum,
        rank() over (
            partition by user_id
            order by date_sum asc
        ) AS rnk
    from data_revenue
),

ranked_and_sorted as (
	select user_id,
	        order_date,
	        date_sum,
	        rnk,
	        lag(date_sum) over (partition by user_id
	        	order by rnk) as previos_date
	from ranked_date
	order by user_id
)

select user_id, date_sum, previos_date, (date_sum - previos_date) as diff
from ranked_and_sorted
where (date_sum - previos_date) >= 1/5 * previos_date or (previos_date - date_sum) >= 1/5 * previos_date
order by user_id