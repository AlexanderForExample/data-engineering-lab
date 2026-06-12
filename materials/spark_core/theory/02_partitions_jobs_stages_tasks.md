# Как Spark выполняет код: partitions, transformations, actions, jobs, stages и tasks

Главная идея: код PySpark не выполняется построчно сразу. Spark строит план, ждёт action, создаёт job, делит его на stages, а stages - на tasks.

## DataFrame логически и физически

Логически DataFrame похож на таблицу: есть строки, колонки и типы. Физически DataFrame разбит на partitions. Partition - это часть данных, которую Spark может обработать отдельно.

```text
DataFrame orders

Partition 1 -> Task 1
Partition 2 -> Task 2
Partition 3 -> Task 3
Partition 4 -> Task 4
```

Связь простая: на stage обычно создаётся примерно по одной task на partition. Поэтому partitions напрямую влияют на parallelism.

## Почему количество partitions важно

Мало partitions:

- мало tasks;
- мало параллелизма;
- часть cores простаивает;
- каждая task может обрабатывать слишком большой кусок данных.

Слишком много partitions:

- много мелких tasks;
- overhead на планирование;
- много мелких shuffle blocks;
- при записи может появиться много маленьких файлов.

Неравномерные partitions:

- одна task работает дольше остальных;
- stage ждёт самую медленную task;
- появляется data skew.

## Transformations и actions

Transformation создаёт новый DataFrame из старого, но не запускает вычисление сразу.

Примеры transformations:

- `filter`;
- `select`;
- `withColumn`;
- `groupBy(...).agg(...)`;
- `join`;
- `distinct`;
- `orderBy`;
- `repartition`.

Action запускает выполнение.

Примеры actions:

- `count()`;
- `show()`;
- `collect()`;
- `take()`;
- `write.parquet(...)`;
- `foreach(...)`.

## Lazy evaluation

Spark ленивый: он не выполняет transformation сразу. Он запоминает, что вы хотите сделать, и строит план.

Это полезно, потому что Spark может оптимизировать цепочку операций. Например, если вы написали `select`, потом `filter`, потом ещё один `select`, Spark не обязан делать три отдельных прохода по данным. Он может объединить часть операций в один physical plan.

## От action к executors

```text
Action
  ↓
Job
  ↓
Stages
  ↓
Tasks
  ↓
Executors
```

Job появляется после action. Если action нет, job обычно не создаётся.

Stage - часть job между shuffle. Если Spark может выполнять операции над каждой partition независимо, они попадают в один stage. Если нужно перераспределить данные между partitions, появляется shuffle, и stage заканчивается.

Task - минимальная единица работы. Task выполняется executor-ом и обычно обрабатывает одну partition на конкретном stage.

## Narrow и wide transformations

Narrow transformation не требует перемешивания данных между partitions. Каждая output partition зависит от одной или нескольких близких input partitions без глобального перераспределения.

Примеры:

- `filter`;
- `select`;
- `withColumn`.

Wide transformation требует перераспределить данные между partitions. Обычно это значит shuffle.

Примеры:

- `groupBy`;
- `join`;
- `distinct`;
- `orderBy`;
- `repartition`.

## Почему stage обычно заканчивается на shuffle

Пока Spark может обрабатывать partitions независимо, он держит операции в одном stage. Но `groupBy("customer_id")` требует собрать одинаковые `customer_id` вместе. Если строки с одним customer лежат на разных executors, их надо переслать. Это и есть граница stage.

```text
Stage 1: read -> filter -> select -> shuffle write
                                      ↓
Stage 2: shuffle read -> aggregate -> result
```

## Самопроверка

- Почему Spark не выполняет `filter` сразу?
- Чем transformation отличается от action?
- Что запускает job?
- Почему stage обычно заканчивается на shuffle?
- Как связаны partition и task?
