# Как читать Spark physical plan: Exchange, Scan, Filter, Project, Join, Aggregate и Sort

Главная идея: Spark physical plan - это карта выполнения. По нему можно понять, откуда Spark читает данные, какие фильтры применяет, какие колонки оставляет, где появляется join, где aggregation, где sort, где shuffle и какой join strategy выбрал optimizer.

## Зачем вообще читать explain

Spark часто выглядит так, будто вы просто пишете Python-код:

```python
orders.filter(...).join(...).groupBy(...).count()
```

Но реально Spark строит план выполнения. Если job медленный, падает по памяти или создаёт слишком много shuffle, смотреть только на Python-код недостаточно. Нужно увидеть, во что Spark превратил ваш код.

`explain` помогает ответить на вопросы:

- откуда читаются данные;
- какие фильтры применяются рано;
- какие колонки реально нужны;
- есть ли shuffle;
- какой join выбран;
- используется ли broadcast;
- включён ли AQE;
- почему появились дополнительные stages.

## Какие бывают планы

У Spark SQL есть несколько уровней плана.

Parsed logical plan - Spark только разобрал выражение. На этом уровне он ещё не знает все типы, таблицы и детали.

Analyzed logical plan - Spark проверил колонки, типы, таблицы, функции.

Optimized logical plan - Catalyst optimizer упростил план: протолкнул фильтры, убрал лишние колонки, объединил выражения.

Physical plan - Spark выбрал конкретные физические операторы: scan, filter, project, hash aggregate, sort merge join, broadcast hash join, exchange.

Новичку чаще всего полезен:

```python
df.explain("formatted")
```

Он показывает physical plan в более читаемом виде, чем обычный `explain()`.

Источник по SQL `EXPLAIN`: https://spark.apache.org/docs/latest/sql-ref-syntax-qry-explain.html

## Как читать план

План чаще всего читают снизу вверх.

Почему снизу вверх: нижние операторы ближе к источникам данных. Сначала Spark читает файлы или таблицы, затем применяет filter/project, затем join/aggregate/sort, затем отдаёт результат action.

Если план выглядит большим, не пытайтесь понять каждую строку сразу. Идите по слоям:

1. Найдите `Scan`.
2. Найдите `Filter` и `Project`.
3. Найдите `Exchange`.
4. Найдите join operator.
5. Найдите aggregate operator.
6. Найдите `Sort`.
7. Посмотрите, есть ли `AdaptiveSparkPlan`.

## Пример кода

Допустим, у нас есть `orders` и `customers`.

```python
from pyspark.sql import functions as F

result = (
    orders
    .filter(F.col("status") == "paid")
    .select("order_id", "customer_id", "order_amount")
    .join(customers.select("customer_id", "region"), "customer_id")
    .groupBy("region")
    .agg(
        F.count("*").alias("orders_cnt"),
        F.sum("order_amount").alias("revenue")
    )
    .orderBy(F.desc("revenue"))
)

result.explain("formatted")
```

Реальный вывод зависит от версии Spark, настроек AQE, статистики и broadcast threshold. Ниже - типичный смысл такого плана, а не обещание байт-в-байт одинакового вывода.

## Упрощённый фрагмент physical plan

```text
AdaptiveSparkPlan
+- Sort [revenue DESC]
   +- Exchange rangepartitioning(revenue DESC)
      +- HashAggregate(keys=[region], functions=[count, sum])
         +- Exchange hashpartitioning(region)
            +- HashAggregate(keys=[region], functions=[partial_count, partial_sum])
               +- Project [region, order_amount]
                  +- SortMergeJoin [customer_id], [customer_id], Inner
                     :- Sort [customer_id ASC]
                     :  +- Exchange hashpartitioning(customer_id)
                     :     +- Project [order_id, customer_id, order_amount]
                     :        +- Filter [status = paid]
                     :           +- Scan parquet orders
                     +- Sort [customer_id ASC]
                        +- Exchange hashpartitioning(customer_id)
                           +- Project [customer_id, region]
                              +- Scan parquet customers
```

Теперь разберём этот план не как страшный текст, а как последовательность решений Spark.

## `Scan`

`Scan` означает чтение данных из источника.

Примеры:

```text
Scan parquet orders
Scan csv events
Scan ExistingRDD
Range
```

Что смотреть:

- формат данных: Parquet, CSV, JSON, table;
- какие колонки читаются;
- есть ли pushed filters;
- сколько partitions получается при чтении.

Если вы выбрали только 3 колонки из 50, хороший план должен читать только нужные колонки, особенно для Parquet/ORC.

## `Filter`

`Filter` отбрасывает строки.

```text
Filter [status = paid]
```

Обычно это narrow operation: каждая partition фильтруется независимо. Сам по себе `Filter` не требует shuffle.

Что важно: фильтр лучше применять до join и aggregation, если бизнес-логика это позволяет. Меньше строк до shuffle - дешевле shuffle.

## `Project`

`Project` выбирает или вычисляет колонки.

```text
Project [order_id, customer_id, order_amount]
```

В коде это часто:

- `select`;
- часть `withColumn`;
- вычисление выражений;
- удаление ненужных колонок.

`Project` обычно narrow operation. Он важен для оптимизации: если перед join оставить только нужные колонки, Spark будет меньше читать, меньше сериализовать и меньше передавать через shuffle.

## `Exchange`

`Exchange` - самый важный сигнал для начинающего.

`Exchange` означает, что Spark меняет распределение данных. Очень часто это shuffle boundary.

Примеры:

```text
Exchange hashpartitioning(customer_id, 8)
Exchange hashpartitioning(region, 8)
Exchange rangepartitioning(revenue DESC, 8)
BroadcastExchange
```

`Exchange hashpartitioning(customer_id)` означает: Spark перераспределяет строки так, чтобы одинаковые `customer_id` попали в одну и ту же target partition. Это нужно для join или groupBy по ключу.

`Exchange rangepartitioning(revenue DESC)` часто появляется перед global sort/orderBy. Spark должен разложить данные по диапазонам значений, чтобы получить глобально отсортированный результат.

Что смотреть:

- по какой колонке repartition;
- сколько partitions;
- перед какой операцией появился Exchange;
- можно ли уменьшить данные до Exchange.

## `HashAggregate`

`HashAggregate` выполняет aggregation.

Часто он встречается два раза:

```text
HashAggregate(keys=[region], functions=[partial_count, partial_sum])
Exchange hashpartitioning(region)
HashAggregate(keys=[region], functions=[count, sum])
```

Почему два раза:

- первый `HashAggregate` делает partial aggregation внутри каждой partition;
- затем `Exchange` собирает одинаковые ключи вместе;
- второй `HashAggregate` считает финальный результат.

Это похоже на идею combiner в MapReduce: сначала уменьшить объём локально, потом передать меньше данных через shuffle.

## `Sort`

`Sort` сортирует данные.

Сортировка может появиться по разным причинам:

- вы явно вызвали `orderBy`;
- Spark выбрал `SortMergeJoin`, которому нужны отсортированные стороны;
- требуется range partitioning для глобальной сортировки.

Важно отличать локальную сортировку внутри partition от глобального `orderBy`. Глобальный `orderBy` почти всегда дорогой, потому что требует перераспределения данных.

## `SortMergeJoin`

`SortMergeJoin` - join strategy для больших таблиц.

Обычно план выглядит так:

```text
SortMergeJoin [customer_id], [customer_id]
:- Sort
:  +- Exchange hashpartitioning(customer_id)
+- Sort
   +- Exchange hashpartitioning(customer_id)
```

Что происходит:

- обе стороны join shuffle-ятся по ключу;
- обе стороны сортируются по ключу;
- затем Spark сливает отсортированные потоки.

Это надёжная стратегия для больших данных, но она дорогая: shuffle + sort на обеих сторонах.

## `BroadcastHashJoin`

`BroadcastHashJoin` появляется, когда Spark решает разослать маленькую таблицу на executors.

Типичный план:

```text
BroadcastHashJoin [customer_id], [customer_id], Inner, BuildRight
:- Scan parquet orders
+- BroadcastExchange
   +- Scan parquet customers
```

Что происходит:

- маленькая сторона join собирается и рассылается executors;
- большая сторона не обязана shuffle-иться по join key;
- каждая partition большой стороны делает lookup в локальной hash table.

Broadcast полезен, если справочник действительно маленький. Если broadcast-таблица большая, можно получить memory pressure на executors.

## `BroadcastExchange`

`BroadcastExchange` - подготовка маленькой стороны join для рассылки.

Это не то же самое, что `Exchange hashpartitioning` для shuffle join. Но это всё равно передача данных: Spark должен подготовить broadcast relation и доставить её executors.

Сигнал для диагностики: если вы ожидали broadcast, ищите `BroadcastHashJoin` и `BroadcastExchange`. Если вместо них `SortMergeJoin` и два `Exchange hashpartitioning`, значит Spark не broadcast-ит сторону join.

## `AdaptiveSparkPlan`

`AdaptiveSparkPlan` означает, что включён AQE: `spark.sql.adaptive.enabled=true`.

При AQE Spark может изменить план во время выполнения:

- объединить маленькие shuffle partitions;
- заменить SortMergeJoin на BroadcastHashJoin;
- оптимизировать skew join;
- использовать runtime statistics.

Важно: план до выполнения и после выполнения могут отличаться. В notebook полезно делать `explain("formatted")` до action и после action, особенно в AQE-практиках.

## Как по плану понять, что будет shuffle

Ищите:

```text
Exchange hashpartitioning(...)
Exchange rangepartitioning(...)
```

Частые причины:

- `groupBy`;
- `join` без broadcast;
- `distinct`;
- `orderBy`;
- `repartition`.

Если видите `Exchange`, задайте вопросы:

- какая операция его вызвала;
- сколько данных до Exchange;
- можно ли отфильтровать строки раньше;
- можно ли убрать ненужные колонки раньше;
- можно ли broadcast-ить маленькую сторону join;
- разумное ли количество shuffle partitions.

## Как связать plan со Spark UI

`explain` показывает план, Spark UI показывает фактическое выполнение.

Сопоставляйте так:

| В плане | В Spark UI |
|---|---|
| `Exchange hashpartitioning` | граница stages, Shuffle Write/Read |
| `SortMergeJoin` | stages с shuffle и sort, возможный spill |
| `BroadcastHashJoin` | SQL tab с BroadcastExchange, меньше shuffle большой стороны |
| `HashAggregate` | aggregation stage, иногда partial и final aggregate |
| `Sort` | stage с сортировкой, возможный spill |
| `AdaptiveSparkPlan` | SQL tab может показать initial/final adaptive plan |

## Мини-чеклист чтения плана

1. Прочитайте план снизу вверх.
2. Найдите все `Scan`.
3. Проверьте, читаются ли только нужные колонки.
4. Найдите `Filter`: применяются ли фильтры до join/shuffle.
5. Найдите все `Exchange`: это главные кандидаты на shuffle.
6. Посмотрите join strategy: `SortMergeJoin` или `BroadcastHashJoin`.
7. Найдите aggregates: есть ли partial/final aggregation.
8. Найдите sort/orderBy.
9. Проверьте AQE.
10. Сравните план со Spark UI после action.

## Самопроверка
- Что означает `Project` и чем он отличается от `Filter`?
- Почему `Exchange` - важный сигнал?
- Почему `HashAggregate` часто встречается два раза?
- Чем `SortMergeJoin` отличается от `BroadcastHashJoin`?
- Как понять по плану, что будет shuffle?
- Почему при включённом AQE план может измениться после выполнения?
