# Домашнее задание: продолжить загрузку `orders.json`

На семинаре мы начали разбирать файл `orders.json` и успели загрузить таблицу `stg.orders`.

Сейчас у вас уже должна быть таблица заказов примерно такого вида:

```sql
CREATE TABLE stg.orders (
    order_id BIGINT PRIMARY KEY,
    user_id BIGINT,
    city TEXT,
    created_at TIMESTAMPTZ,
    status TEXT
);
```

В домашнем задании нужно продолжить работу с тем же файлом `orders.json`: разобрать вложенные части заказа, загрузить их в отдельные таблицы и в конце собрать небольшую витрину.

---

## Что нужно сделать

### 1. Загрузить позиции заказов

В `orders.json` у каждого заказа есть массив товаров:

```text
orders[].items[]
```

Нужно разобрать этот массив и загрузить его в отдельную таблицу `stg.order_items`.

Одна строка в `stg.order_items` = одна позиция внутри заказа.

Примерный каркас таблицы:

```sql
CREATE TABLE IF NOT EXISTS stg.order_items (
    -- id заказа
    order_id BIGINT NOT NULL,

    -- номер позиции внутри заказа
    line_no INT NOT NULL,

    -- дальше добавьте поля, которые нужны для описания товара в заказе
    -- подумайте, какие поля стоит взять из item

    PRIMARY KEY (order_id, line_no)
);
```

Минимально в таблице должны быть поля:

```text
order_id
line_no
product_id
sku
quantity
unit_price
item_amount
category
```

Что нужно учесть:

```text
item_amount нужно посчитать как quantity * unit_price
category можно взять как первый элемент из category_path
```

---

### 2. Загрузить платежи

В `orders.json` у каждого заказа есть объект с платежом:

```text
orders[].payment
```

Нужно разобрать этот объект и загрузить его в отдельную таблицу `stg.payments`.

Одна строка в `stg.payments` = один платёж по заказу.

Примерный каркас таблицы:

```sql
CREATE TABLE IF NOT EXISTS stg.payments (
    -- id платежа
    payment_id TEXT PRIMARY KEY,

    -- id заказа, к которому относится платёж
    order_id BIGINT

    -- дальше добавьте поля, которые нужны для описания платежа
);
```

Минимально в таблице должны быть поля:

```text
payment_id
order_id
status
amount
currency
```


---

# Дополнительное задание

В `orders.json` у платежа есть массив попыток:

```text
orders[].payment.attempts[]
```

Нужно загрузить его в таблицу:

```text
stg.payment_attempts
```

Одна строка в `stg.payment_attempts` = одна попытка платежа.

Примерный каркас таблицы:

```sql
CREATE TABLE IF NOT EXISTS stg.payment_attempts (
    payment_id TEXT NOT NULL,
    attempt_no INT NOT NULL,

    -- дальше добавьте поля, которые описывают попытку платежа

    PRIMARY KEY (payment_id, attempt_no)
);
```

Минимально в таблице должны быть поля:

```text
payment_id
attempt_no
provider
status
error_code
attempted_at
```

Что нужно учесть:

```text
error_code есть не у всех попыток
в некоторых записях error может быть null
```

---

# Задание со звёздочкой

После того как обычная загрузка работает, попробуйте убрать дублирование кода.

Сейчас для каждой таблицы вы, скорее всего, делаете одно и то же:

```text
1. собираете DataFrame;
2. превращаете DataFrame в список tuple;
3. пишете INSERT;
4. пишете ON CONFLICT DO UPDATE;
5. вызываете executemany;
6. делаете commit.
```

Попробуйте написать общую функцию:

```python
load_df_to_postgres(
    df=order_items_df,
    table_name="stg.order_items",
    conflict_columns=["order_id", "line_no"],
)
```

Функция должна:

```text
1. принимать DataFrame;
2. принимать имя таблицы;
3. принимать список колонок для ON CONFLICT;
4. сама брать список колонок из DataFrame;
5. сама собирать INSERT;
6. сама собирать DO UPDATE SET;
7. загружать данные через psycopg;
8. не падать, если DataFrame пустой.
```

Функция должна работать минимум для таблиц:

```text
stg.orders
stg.order_items
stg.payments
stg.payment_attempts
```

