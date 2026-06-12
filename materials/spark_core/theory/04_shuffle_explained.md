# Shuffle в Spark: почему groupBy и join дорогие

Главная идея: shuffle возникает, когда Spark должен собрать связанные данные из разных partitions/executors вместе. Это дорого, потому что включает network I/O, disk I/O, serialization, memory pressure и дополнительные stages.

## Почему filter/select обычно дешёвые

`filter` и `select` обычно работают независимо внутри каждой partition. Spark читает partition, оставляет нужные строки и колонки, и не обязан пересылать строки на другой executor.

```text
Partition 1 -> filter/select -> Partition 1'
Partition 2 -> filter/select -> Partition 2'
Partition 3 -> filter/select -> Partition 3'
```

Это narrow transformations.

## Почему groupBy требует shuffle

Возьмём код:

```python
orders.groupBy("customer_id").count()
```

До `groupBy` одинаковые `customer_id` могут лежать в разных partitions:

```text
Partition 1: customer_id = 1, 2, 3
Partition 2: customer_id = 2, 3, 4
Partition 3: customer_id = 1, 4, 5
```

Чтобы посчитать итоговый `count` по customer, Spark должен собрать одинаковые ключи вместе:

```text
customer_id = 1 -> одна reduce partition
customer_id = 2 -> другая reduce partition
customer_id = 3 -> третья reduce partition
```

Это невозможно сделать только локально внутри старых partitions. Поэтому Spark делает shuffle.

## Shuffle write и shuffle read

Shuffle write - стадия, где map-side tasks раскладывают данные по будущим reduce partitions и пишут промежуточные shuffle blocks.

Shuffle read - стадия, где reduce-side tasks читают нужные shuffle blocks, часто с разных executors.

```text
Stage 1: map-side
read partitions -> partial work -> shuffle write

Stage 2: reduce-side
shuffle read -> final aggregate/join/sort
```

## Схема shuffle across executors

![Data Shuffle Across Executors](https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-aws-glue-for-apache-spark/images/data-shuffle-across-executors.png)

Источник: AWS Prescriptive Guidance, Optimize shuffles: https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-aws-glue-for-apache-spark/optimize-shuffles.html

Что важно на этой схеме:

- map-side - executors, которые пишут shuffle data после первой части вычислений;
- reduce-side - executors, которые читают данные, уже перераспределённые по новым partitions;
- shuffle write - запись промежуточных данных;
- shuffle read - чтение этих данных другой стадией;
- сеть появляется потому, что reduce task может читать blocks с разных executors;
- диск появляется потому, что shuffle blocks материализуются как промежуточные файлы и могут spill-иться.

## Почему join часто требует shuffle

Для обычного join Spark должен сопоставить строки с одинаковым ключом. Если таблица `orders` разбита одним способом, а `customers` другим, строки с одинаковым `customer_id` могут находиться на разных executors.

Spark должен привести обе стороны join к совместимому partitioning по join key. Обычно это означает `Exchange` и shuffle.

Исключение: broadcast join. Если одна таблица маленькая, Spark может разослать её копию на executors и избежать shuffle большой таблицы.

![Broadcast join and shuffle join](https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-aws-glue-for-apache-spark/images/broadcast-join-shuffle-join.png)

Источник: AWS Prescriptive Guidance, Optimize shuffles: https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-aws-glue-for-apache-spark/optimize-shuffles.html

Что важно на этой схеме: broadcast join отправляет маленькую таблицу к каждой partition большой таблицы, а shuffle join перераспределяет данные по ключу. Поэтому broadcast может быть дешевле, если справочник действительно маленький.

## Exchange в explain

В `DataFrame.explain("formatted")` оператор `Exchange` - важный сигнал. Он часто означает, что Spark меняет распределение данных: hash partitioning, range partitioning, broadcast exchange или single partition exchange.

Если вы видите `Exchange hashpartitioning(customer_id, 8)`, это почти всегда граница shuffle stage.

## Как shuffle виден в Spark UI

В Spark UI смотрите:

- Stages tab: Shuffle Read, Shuffle Write, Spill Memory, Spill Disk;
- SQL tab: physical plan, `Exchange`, `SortMergeJoin`, `BroadcastHashJoin`;
- Executors tab: shuffle read/write по executors, GC time.

![Shuffle spill in Spark UI](https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-aws-glue-for-apache-spark/images/shuffle-spill.png)

Источник: AWS Prescriptive Guidance, Optimize shuffles: https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-aws-glue-for-apache-spark/optimize-shuffles.html

Что важно на этой схеме: Spark UI показывает Shuffle Read и Shuffle Spill. Если spill большой, executor-ам не хватает памяти для промежуточных данных, и Spark вынужден использовать диск.

## Почему shuffle дорогой

```text
Shuffle cost =
network I/O
+ disk I/O
+ serialization/deserialization
+ memory pressure
+ spill
+ дополнительный stage
```

Операции, которые часто вызывают shuffle:

- `groupBy`;
- `join`;
- `distinct`;
- `orderBy`;
- `repartition`.

## Самопроверка

- Почему groupBy требует shuffle?
- Почему filter обычно не требует shuffle?
- Что такое Shuffle Write?
- Что такое Shuffle Read?
