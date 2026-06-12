# Setup и учебный датасет

Цель этого файла - подготовить одинаковые данные для всех лабораторных. Практики не зависят от внешних CSV: все таблицы генерируются локально через PySpark и сохраняются в Parquet.

## Как запустить Spark

Вариант 1: локальный Jupyter/PySpark на вашей машине.

```bash
jupyter lab
```

Вариант 2: окружение этого репозитория.

```bash
make jupyter
```

Откройте JupyterLab: `http://localhost:8888`.

Spark UI будет доступен на `http://localhost:4040`, пока существует активный `SparkSession`.

## Базовый SparkSession

На первых практиках AQE выключен специально. Так проще увидеть shuffle, stages и количество tasks без адаптивного изменения плана.

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("spark-practice")
    .master("local[*]")
    .config("spark.driver.memory", "2g")
    .config("spark.driver.maxResultSize", "512m")
    .config("spark.sql.shuffle.partitions", "8")
    .config("spark.sql.adaptive.enabled", "false")
    .getOrCreate()
)

spark.sparkContext.setLogLevel("WARN")
print(spark.version)
print(spark.sparkContext.uiWebUrl)
```

Если вы запускаете внутри Docker-окружения репозитория и хотите использовать Spark Standalone, замените `.master("local[*]")` на `.master("spark://spark-master:7077")`. Для лабораторных это не обязательно: они рассчитаны на `local[*]`.

## Генерация датасета

Выполните этот код один раз перед практиками. Он создаст таблицы:

- `customers`;
- `orders`;
- `products`;
- `order_items`;
- `events`.

Данные содержат join-ключи, даты, категории, числовые поля и перекошенный ключ `skew_key`, где около 80% событий имеют значение `hot_key`.

```python
from pathlib import Path
from pyspark.sql import functions as F

base_path = Path("spark_core_data").absolute()
base_uri = base_path.as_uri()
print(base_uri)

customer_count = 10_000
order_count = 120_000
product_count = 1_000
item_count = 300_000
event_count = 200_000

customers = (
    spark.range(customer_count)
    .withColumnRenamed("id", "customer_id")
    .withColumn("customer_name", F.concat(F.lit("customer_"), F.col("customer_id")))
    .withColumn("region", F.expr("array('north','south','east','west','central')[int(customer_id % 5)]"))
    .withColumn("segment", F.expr("array('new','regular','vip')[int(customer_id % 3)]"))
)

products = (
    spark.range(product_count)
    .withColumnRenamed("id", "product_id")
    .withColumn("category", F.expr("array('books','electronics','home','sport','beauty','toys')[int(product_id % 6)]"))
    .withColumn("price", (F.rand(11) * 200 + 5).cast("decimal(10,2)"))
)

orders = (
    spark.range(order_count)
    .withColumnRenamed("id", "order_id")
    .withColumn("customer_id", (F.col("order_id") % customer_count).cast("long"))
    .withColumn("order_date", F.expr("date_add(date'2024-01-01', int(order_id % 180))"))
    .withColumn("status", F.expr("array('created','paid','shipped','cancelled')[int(order_id % 4)]"))
    .withColumn("order_amount", (F.rand(21) * 500 + 20).cast("decimal(10,2)"))
)

order_items = (
    spark.range(item_count)
    .withColumnRenamed("id", "order_item_id")
    .withColumn("order_id", (F.col("order_item_id") % order_count).cast("long"))
    .withColumn("product_id", (F.col("order_item_id") % product_count).cast("long"))
    .withColumn("quantity", (F.col("order_item_id") % 5 + 1).cast("int"))
    .withColumn("item_price", (F.rand(31) * 200 + 5).cast("decimal(10,2)"))
)

events = (
    spark.range(event_count)
    .withColumnRenamed("id", "event_id")
    .withColumn("customer_id", (F.col("event_id") % customer_count).cast("long"))
    .withColumn("event_date", F.expr("date_add(date'2024-01-01', int(event_id % 180))"))
    .withColumn("event_type", F.expr("array('view','click','cart','purchase')[int(event_id % 4)]"))
    .withColumn("skew_key", F.when(F.col("event_id") < event_count * 0.8, F.lit("hot_key")).otherwise(F.concat(F.lit("key_"), (F.col("event_id") % 1000))))
    .withColumn("event_value", (F.rand(41) * 100).cast("double"))
)

tables = {
    "customers": customers.repartition(4),
    "orders": orders.repartition(8),
    "products": products.repartition(2),
    "order_items": order_items.repartition(12),
    "events": events.repartition(8),
}

for name, df in tables.items():
    path = f"{base_uri}/{name}"
    df.write.mode("overwrite").parquet(path)
    print(name, df.count(), path)
```

## Проверка, что всё работает

```python
orders = spark.read.parquet(f"{base_uri}/orders")
customers = spark.read.parquet(f"{base_uri}/customers")
events = spark.read.parquet(f"{base_uri}/events")

orders.printSchema()
print("orders partitions:", orders.rdd.getNumPartitions())
print("Spark UI:", spark.sparkContext.uiWebUrl)
orders.groupBy("status").count().show()
events.groupBy("skew_key").count().orderBy(F.desc("count")).show(5)
```

## Что смотреть в Spark UI

- Jobs: какая action создала job.
- Stages: сколько stages, сколько tasks, были ли Shuffle Read/Write и spill.
- SQL: physical plan, `Exchange`, `BroadcastHashJoin`, `SortMergeJoin`.
- Executors: GC time, shuffle read/write, storage memory.
- Storage: появится после cache/persist.

## Если данные не найдены

Сначала повторно выполните генерацию датасета. Все практики ожидают путь `spark_core_data` относительно текущей рабочей директории notebook.
