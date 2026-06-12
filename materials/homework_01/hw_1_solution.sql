-- E1
SELECT  i.order_id,
        i.product_id,
        p.product_name,
        i.price AS price_at_purchase,
        p.price AS current_price,
        ABS(i.price - p.price) AS price_diff
FROM    lecture_01.order_items i
INNER JOIN lecture_01.products p
        ON i.product_id = p.product_id
WHERE i.price != p.price;

-- E2
SELECT  order_id,
        COUNT(*) AS total_positions,
        SUM(quantity) AS total_quantity
FROM lecture_01.order_items
GROUP BY order_id
HAVING SUM(quantity) > 5;

-- E3
SELECT  i.product_id,
        p.product_name,
        p.price AS current_price,
        MAX(i.price) AS max_price,
        (MAX(i.price) - p.price) AS price_diff
FROM    lecture_01.order_items i
INNER JOIN lecture_01.products p
        ON i.product_id = p.product_id
WHERE   i.price > p.price
GROUP BY i.product_id, p.product_name, p.price;

-- E4        
SELECT  u.user_id,
        u.email,
        CAST(u.registered_at AS DATE) AS registration_date,
        o.order_id,
        o.order_date
FROM lecture_01.users u
INNER JOIN lecture_01.orders o
        ON u.user_id = o.user_id
WHERE u.registered_at > o.order_date;

-- E5
SELECT i.order_id,
       MAX(p.category) AS category,
       COUNT(p.product_id) AS unique_products,
       SUM(i.quantity * i.price) AS order_amount
FROM   lecture_01.order_items i
INNER JOIN lecture_01.products p
        ON i.product_id = p.product_id
GROUP BY i.order_id
HAVING COUNT(DISTINCT p.category) = 1;

-- M1
SELECT order_id,
       SUM(quantity * price) AS order_amount,
       MAX(quantity * price) AS most_expensive_position,
       ROUND(MAX(quantity * price) / SUM(quantity * price) * 100, 2) AS most_expensive_percentage
FROM lecture_01.order_items
GROUP BY order_id;

-- M2
WITH user_details AS (
        SELECT 
               u.user_id,
               u.email,
               COUNT(o.order_id) OVER (PARTITION BY u.user_id) AS orders_cnt,
               AVG(o.amount) OVER (PARTITION BY u.user_id) AS avg_amount,
               o.amount AS last_amount,
               ROW_NUMBER() OVER (PARTITION BY u.user_id ORDER BY o.order_date DESC) AS rnk
        FROM lecture_01.users u
        INNER JOIN lecture_01.orders o
                ON u.user_id = o.user_id
        WHERE o.status = 'paid'
)
SELECT user_id,
       email,
       orders_cnt,
       avg_amount,
       last_amount,
       ABS(last_amount - avg_amount) AS last_avg_diff
FROM user_details 
WHERE rnk = 1 AND orders_cnt > 1 AND last_amount > avg_amount;

-- M3
WITH paid_orders AS (
        SELECT o.order_id,
               p.category,
               COUNT(p.category) OVER (PARTITION BY o.order_id) AS unique_categories
        FROM lecture_01.orders o
        INNER JOIN lecture_01.order_items i
                ON o.order_id = i.order_id
        INNER JOIN lecture_01.products p
                ON i.product_id = p.product_id
        WHERE o.status = 'paid'
        GROUP BY o.order_id, p.category
)

SELECT category,
       SUM(CASE WHEN unique_categories > 1 THEN 1 ELSE 0 END) AS multi_category_orders,
       COUNT(*) AS total_orders,
       ROUND((SUM(CASE WHEN unique_categories > 1 THEN 1 ELSE 0 END) / CAST(COUNT(*) AS DECIMAL)), 2) AS multi_category_part
FROM paid_orders
GROUP BY category;

-- H1
WITH user_category_details AS (
        SELECT u.user_id,
               u.email,
               p.category,
               SUM(i.quantity * i.price) AS category_sum
        FROM lecture_01.users u
        INNER JOIN lecture_01.orders o
                ON u.user_id = o.user_id
        INNER JOIN lecture_01.order_items i
                ON o.order_id = i.order_id
        INNER JOIN lecture_01.products p
                ON i.product_id = p.product_id
        WHERE o.status = 'paid'
        GROUP BY u.user_id, u.email, p.category
),
full_user_details AS (
        SELECT  user_id,
                email,
                category,
                category_sum,
                SUM(category_sum) OVER (PARTITION BY user_id) AS total_sum,
                DENSE_RANK() OVER (PARTITION BY user_id ORDER BY category_sum DESC) AS rnk
        FROM user_category_details
)
SELECT user_id,
       email,
       category AS top_category,
       category_sum,
       total_sum,
       ROUND(CAST(category_sum AS DECIMAL) / total_sum, 2) AS category_to_total
FROM full_user_details
WHERE rnk = 1;
       
-- H2

WITH user_orders_details AS (
        SELECT user_id,
               amount AS cur_order,
               LAG(amount, 1, NULL) OVER (PARTITION BY user_id ORDER BY order_date) AS prev_order
        FROM lecture_01.orders
        WHERE status = 'paid'
)

SELECT *,
       ABS(cur_order - prev_order) AS prev_to_cur_diff,
       ROUND(ABS(cur_order - prev_order) / CAST(prev_order AS DECIMAL) * 100, 2) AS percent_diff
FROM user_orders_details
WHERE prev_order IS NOT NULL AND ABS(cur_order - prev_order) / CAST(prev_order AS DECIMAL) * 100 > 20;

-- H3
WITH paid_orders_categories AS (
        SELECT i.order_id,
               p.category,
               SUM(i.quantity * i.price) AS category_sum
        FROM lecture_01.order_items i
        INNER JOIN lecture_01.products p
                ON i.product_id = p.product_id
        INNER JOIN lecture_01.orders o
                ON i.order_id = o.order_id
        WHERE o.status = 'paid'
        GROUP BY i.order_id, p.category
),
full_orders_stats AS (
        SELECT order_id,
               category,
               category_sum,
               SUM(category_sum) OVER (PARTITION BY order_id) AS total_sum,
               ROUND(category_sum / CAST(SUM(category_sum) OVER (PARTITION BY order_id) AS DECIMAL), 2) AS cat_to_total
        FROM paid_orders_categories
)

SELECT order_id,
       category,
       category_sum AS top_category_sum,
       total_sum,
       cat_to_total AS top_cat_to_total
FROM full_orders_stats
WHERE cat_to_total > 0.8;

-- H4 (не учитывая самый первый заказ пользователя)
WITH user_categories_details AS (
        SELECT o.user_id,
               p.category,
               MIN(o.order_date) AS first_cat_order
        FROM lecture_01.orders o
        INNER JOIN lecture_01.order_items i
                ON o.order_id = i.order_id
        INNER JOIN lecture_01.products p
                ON i.product_id = p.product_id
        GROUP BY o.user_id, p.category            
),
user_categories_ranking AS (
        SELECT  ucd.user_id,
                u.email,
                ucd.category,
                ucd.first_cat_order,
                RANK() OVER (PARTITION BY ucd.user_id ORDER BY ucd.first_cat_order) AS cat_number
        FROM user_categories_details ucd
        INNER JOIN lecture_01.users u
                ON ucd.user_id = u.user_id
)
SELECT * FROM user_categories_ranking WHERE cat_number != 1;

-- H5
WITH order_items_details AS (
        SELECT order_id,
               SUM(quantity * price) AS total_price
        FROM lecture_01.order_items
        GROUP BY order_id
),
full_details AS (
        SELECT oid.order_id,
               o.status,
               o.user_id,
               o.amount,
               oid.total_price,
               ABS(oid.total_price - o.amount) AS abs_diff,
               ROUND(ABS(oid.total_price - o.amount) / CAST(o.amount AS DECIMAL) * 100, 2) AS percent_diff
        FROM order_items_details oid
        INNER JOIN lecture_01.orders o
        ON oid.order_id = o.order_id
)
SELECT * FROM full_details WHERE percent_diff > 10;

-- B1
WITH orders_details AS (
        SELECT i.order_id,
               COUNT(i.product_id) AS products_amount,
               COUNT(DISTINCT p.category) AS categories_amount
        FROM lecture_01.order_items i
        INNER JOIN lecture_01.products p
                ON i.product_id = p.product_id
        INNER JOIN lecture_01.orders o
                ON o.order_id = i.order_id
        WHERE o.status = 'paid'
        GROUP BY i.order_id
)
SELECT *, 
ROUND(categories_amount / CAST(products_amount AS DECIMAL), 2) AS diversity_index
FROM orders_details 
ORDER BY diversity_index DESC;

-- B2
WITH orders_details AS (
        SELECT o.user_id,
               MAX(p.category) AS category,
               COUNT(DISTINCT o.order_id) AS total_orders,
               SUM(i.quantity * i.price) AS total_spendings
        FROM lecture_01.order_items i
        INNER JOIN lecture_01.products p
                ON i.product_id = p.product_id
        INNER JOIN lecture_01.orders o
                ON o.order_id = i.order_id
        WHERE o.status = 'paid'
        GROUP BY o.user_id
        HAVING COUNT(DISTINCT p.category) = 1
)
SELECT od.user_id,
       u.email,
       od.category,
       od.total_orders,
       od.total_spendings
FROM orders_details od
INNER JOIN lecture_01.users u
        ON u.user_id = od.user_id;
        
-- B3
WITH orders_details AS (
        SELECT product_id,
               MIN(price) AS min_price,
               MAX(price) AS max_price,
               COUNT(order_id) AS total_orders
        FROM lecture_01.order_items
        GROUP BY product_id
        HAVING MIN(price) != MAX(price)
)

SELECT od.product_id,
       p.product_name,
       od.min_price,
       od.max_price,
       od.max_price - od.min_price AS price_diff,
       od.total_orders
FROM orders_details od
INNER JOIN lecture_01.products p
        ON od.product_id = p.product_id
ORDER BY product_id