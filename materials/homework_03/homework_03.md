# Домашнее задание 03: HDFS, Hive и Spark

В этом задании нужно поработать с небольшим датасетом computer shop.

Данные лежат в папке:

```text
/materials/homework_03/data
```

Таблицы:

- `product.csv` - справочник моделей: производитель, модель, тип устройства.
- `pc.csv` - характеристики и цены ПК.
- `laptop.csv` - характеристики и цены ноутбуков.
- `printer.csv` - характеристики и цены принтеров.

## Часть 1. HDFS

### 1. Создать raw-слой и загрузить исходные данные

Создайте raw-слой в HDFS и загрузите туда исходные файлы:

```text
/warehouse/raw/product/product.csv
/warehouse/raw/pc/pc.csv
```

Исходные локальные файлы:

```text
/materials/homework_03/data/product.csv
/materials/homework_03/data/pc.csv
```

## Часть 2. Hive

SQL можно выполнять через DBeaver.

Подключение:

```text
jdbc:hive2://localhost:10000/default
```

### 2. Создать raw-схему и external tables

Создайте схему `raw`.

Создайте external table `raw.product` над HDFS-путём:

```text
/warehouse/raw/product
```

Схема `raw.product`:

```text
maker STRING
model INT
type STRING
```

Создайте external table `raw.pc` над HDFS-путём:

```text
/warehouse/raw/pc
```

Схема `raw.pc`:

```text
model INT
speed INT
ram INT
hd INT
price INT
```

### 3. Создать ods-схему и партиционированную таблицу

Создайте схему `ods`.

Создайте таблицу `ods.product`, партиционированную по `type`.

Путь таблицы:

```text
/warehouse/ods/product
```

Заполните `ods.product` данными из `raw.product`.

### 4. Hive-запрос с join и агрегацией

Напишите Hive-запрос, который соединяет `raw.product` и `raw.pc` по `model`.

Для каждого производителя ПК выведите:

```text
maker
pc_models_count
avg_price
min_price
max_price
```

## Часть 3. Spark

Используйте шаблон:

```text
materials/homework_03/starter_spark.ipynb
```

Все задачи выполняйте через Spark DataFrame API или Spark SQL.

### 5. Прочитать CSV без автоматического определения типов

Прочитайте четыре файла:

```text
product.csv
pc.csv
laptop.csv
printer.csv
```

Требования:

- `header=True`
- `inferSchema=False`
- вывести `printSchema()` для каждой таблицы
- убедиться, что числовые поля прочитались как `string`

### 6. Привести типы данных

Приведите типы, перезаписав те же переменные:

```text
product
pc
laptop
printer
```

Типы:

- `model` -> `int`
- `speed` -> `int`
- `ram` -> `int`
- `hd` -> `int`
- `screen` -> `double`
- `price` -> `int`

После приведения снова выведите `printSchema()`.

### 7. Убрать крайние модели

Выведите все строки из `product`, кроме:

- трёх моделей с наименьшими номерами;
- трёх моделей с наибольшими номерами.

Ожидаемые колонки результата:

```text
maker, model, type
```

### 8. Средняя цена ПК по скорости

Для каждого значения `speed > 600` найдите среднюю цену ПК с такой же скоростью.

Ожидаемые колонки:

```text
speed, avg_price
```

### 9. Производители с полным покрытием PC-моделей

Найдите производителей ПК, все модели ПК которых из таблицы `product` имеются в таблице `pc`.

Ожидаемые колонки:

```text
maker, product_pc_models, matched_pc_models
```

### 10. Производители ноутбуков, но не принтеров

Найдите производителей, которые выпускают ноутбуки, но не выпускают принтеры.

Ожидаемые колонки:

```text
maker
```

### 11. Все устройства с ценой

Соберите единый DataFrame с колонками:

```text
model, device_type, price
```

Источники:

- `pc`
- `laptop`
- `printer`

Найдите топ-5 самых дорогих устройств.

### 12. Статистика цен по производителю

Соедините `product` с объединённой таблицей цен из задачи 11.

Для каждого `maker` посчитайте:

- количество моделей с ценой;
- среднюю цену;
- минимальную цену;
- максимальную цену.

Ожидаемые колонки:

```text
maker, priced_models_count, avg_price, min_price, max_price
```

### 13. Контроль качества PC-данных

Сравните PC-модели из `product` и таблицу `pc`.

Найдите проблемные строки:

- модель есть в `product` как PC, но отсутствует в `pc`;
- модель есть в `pc`, но отсутствует в `product`.

Добавьте колонку `issue_type` со значениями:

```text
missing_in_pc
missing_in_product
```

### 14. Две самые дешёвые модели внутри каждого типа

Для каждого типа устройства (`PC`, `Laptop`, `Printer`) найдите две модели с минимальной ценой.

Ожидаемые колонки:

```text
type, maker, model, price
```

### 15. Условная агрегация по производителям

Для каждого производителя посчитайте, сколько у него моделей каждого типа:

```text
maker, pc_count, laptop_count, printer_count
```

### 16. Производители с полным покрытием типов

Найдите производителей, у которых есть минимум:

- одна модель `PC`;
- одна модель `Laptop`;
- одна модель `Printer`.

### 17. Bonus: записать результат в Parquet

Запишите результат задачи 12 в HDFS в формате Parquet:

```text
/warehouse/ods/maker_price_stats
```

Кратко ответьте: почему Parquet обычно удобнее CSV для аналитики?
