# Driver, Executor и JVM-память: почему Spark падает по OOM

Главная идея: Driver и Executors - это JVM-процессы. Даже в PySpark значительная часть Spark engine работает внутри JVM. Ошибки памяти нужно понимать через driver memory, executor memory, execution memory, storage memory и memory overhead.

## Почему здесь вообще JVM

Spark написан на Scala и работает на JVM. PySpark - это Python API поверх Spark engine. Когда вы вызываете DataFrame API из Python, Python-код общается с JVM-процессом Spark через Py4J и внутренние механизмы Spark.

Это значит, что в PySpark есть минимум два слоя памяти:

- память JVM, где работает Spark engine;
- память Python worker-ов, где выполняется Python-код, UDF и часть PySpark-логики.

## JVM простыми словами

JVM - виртуальная машина, в которой выполняется Java/Scala-код. У JVM есть heap - область памяти для объектов. Когда объекты больше не нужны, Garbage Collector освобождает память.

GC - это автоматическая уборка памяти. Она полезна, потому что разработчику не нужно вручную освобождать каждый объект. Но GC не бесплатен: чем больше объектов и чем выше давление на память, тем больше времени процесс может тратить на сборку мусора.

Oracle описывает runtime data areas JVM, включая heap, stacks, method area и native method stacks: https://docs.oracle.com/javase/specs/jvms/se17/html/jvms-2.html#jvms-2.5

![Java heap and stack memory diagram](https://www.baeldung.com/wp-content/uploads/2018/07/java-heap-stack-diagram.png)

Источник: Baeldung, Stack Memory and Heap Space in Java: https://www.baeldung.com/java-stack-heap

Что важно на этой схеме: объекты живут в heap, а stack хранит локальные переменные и ссылки на объекты. Для Spark это важно потому, что Driver и Executor - долгоживущие JVM-процессы: если в heap не хватает места под объекты Spark, shuffle-структуры, cache или результат на Driver, процесс может получить OOM. Схема не показывает все области JVM, например metaspace, direct memory и native memory, поэтому ниже мы отдельно проговариваем memory overhead.

## Driver memory vs Executor memory

Driver memory - память процесса Driver. Она нужна для:

- SparkSession и SparkContext;
- планов выполнения;
- metadata;
- результатов actions, которые возвращаются на Driver;
- collected data после `collect()` или `toPandas()`.

Executor memory - память рабочих процессов. Она нужна для:

- выполнения tasks;
- shuffle, join, sort, aggregation;
- cache и persist;
- broadcast blocks;
- внутренних структур Spark.

Если Driver падает после `collect()`, проблема не только в размере `spark.driver.memory`. Часто проблема в самом паттерне: вы пытаетесь забрать распределённые данные в один процесс.

## Execution memory и Storage memory

Spark делит память на области по назначению. Упрощённо:

```text
Executor memory
├── JVM heap
│   ├── execution memory
│   │   ├── join
│   │   ├── groupBy
│   │   ├── sort
│   │   └── shuffle
│   └── storage memory
│       ├── cache
│       ├── persist
│       └── broadcast blocks
├── non-heap / metaspace
├── direct/native memory
└── PySpark workers / overhead
```

Execution memory используется во время вычислений: shuffle, join, sort, aggregation. Если `groupBy`, `join` или `sort` обрабатывают слишком большие partitions, executor может spill-ить на диск или упасть по OOM.

Storage memory используется для хранения данных между действиями: cache, persist, broadcast blocks. Cache может ускорить повторное использование DataFrame, но если закэшировать слишком много, он вытеснит полезную память и начнёт мешать execution memory.

Apache Spark Tuning Guide объясняет, что execution memory используется для shuffles, joins, sorts and aggregations, а storage memory - для caching и внутренних данных: https://spark.apache.org/docs/latest/tuning.html#memory-management-overview

## Memory overhead

`spark.executor.memory` - это не вся память контейнера executor. Есть ещё memory overhead. Туда попадают:

- Python workers в PySpark;
- native memory;
- direct buffers;
- thread stacks;
- container overhead;
- часть off-heap использования.

Поэтому PySpark-задача может падать не потому, что мало heap, а потому что контейнер превысил общий memory limit. В YARN/Kubernetes это часто выглядит как `memory overhead exceeded` или container killed.

## Почему collect и toPandas убивают Driver

`collect()` возвращает все строки результата на Driver. `toPandas()` делает ещё тяжелее: данные должны оказаться в памяти Driver и затем стать pandas DataFrame. Даже если executors успешно обработали данные, Driver может не вместить результат.

Правильнее:

- писать результат в storage;
- использовать `limit` для отладки;
- агрегировать данные до маленького результата;
- смотреть sample, а не весь DataFrame.

## Почему groupBy, join и sort давят на executor memory

Эти операции часто требуют shuffle и промежуточных структур:

- `groupBy` держит агрегаты;
- `join` строит hash table или сортирует стороны join;
- `sort` требует буферы сортировки;
- shuffle пишет и читает промежуточные данные.

Если partitions слишком большие или данные перекошены, одна task может получить огромный кусок данных. Тогда увеличение общего количества executors не всегда поможет: проблемная task всё равно выполняется в одном executor.

## Важные параметры

`spark.driver.memory` существует, потому что Driver тоже JVM-процесс. Увеличение помогает, если Driver реально работает с метаданными или небольшими результатами. Но если вы делаете `collect()` на большом DataFrame, правильнее убрать `collect()`.

`spark.driver.maxResultSize` ограничивает размер результата, который можно вернуть на Driver. Это предохранитель от случайного вывоза больших данных в один процесс.

`spark.executor.memory` задаёт heap executor-а. Помогает, когда tasks не помещаются в execution/storage memory, но не лечит skew и слишком крупные partitions как архитектурную проблему.

`spark.executor.memoryOverhead` задаёт дополнительную память сверх heap. Особенно важен для PySpark, Kubernetes и YARN.

`spark.executor.cores` задаёт, сколько tasks executor может выполнять параллельно. Слишком много cores на executor может увеличить конкуренцию за одну heap-память.

`spark.executor.instances` задаёт количество executors. Больше executors даёт больше параллелизма и памяти суммарно, но не исправляет один огромный skewed task.

## Самопроверка

- Почему executor.memory и memoryOverhead - не одно и то же?
- Почему `collect()` может убить driver?
- Что давит на execution memory?
- Что давит на storage memory?
- Почему PySpark-задачи могут падать по overhead?
