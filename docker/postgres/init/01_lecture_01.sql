DROP SCHEMA IF EXISTS lecture_01 CASCADE;
CREATE SCHEMA lecture_01;

CREATE TABLE lecture_01.users (
    user_id INTEGER PRIMARY KEY,
    email TEXT NOT NULL,
    city TEXT NOT NULL,
    registered_at TIMESTAMP NOT NULL
);

CREATE TABLE lecture_01.products (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL,
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE lecture_01.orders (
    order_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES lecture_01.users(user_id),
    order_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('created', 'paid', 'cancelled')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0)
);

CREATE TABLE lecture_01.order_items (
    order_id INTEGER NOT NULL REFERENCES lecture_01.orders(order_id),
    product_id INTEGER NOT NULL REFERENCES lecture_01.products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (order_id, product_id)
);

COPY lecture_01.users (user_id, email, city, registered_at)
FROM '/data/lecture_01/users.csv'
WITH (FORMAT csv, HEADER true);

COPY lecture_01.products (product_id, product_name, category, price)
FROM '/data/lecture_01/products.csv'
WITH (FORMAT csv, HEADER true);

COPY lecture_01.orders (order_id, user_id, order_date, status, amount)
FROM '/data/lecture_01/orders.csv'
WITH (FORMAT csv, HEADER true);

COPY lecture_01.order_items (order_id, product_id, quantity, price)
FROM '/data/lecture_01/order_items.csv'
WITH (FORMAT csv, HEADER true);
