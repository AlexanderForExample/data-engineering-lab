# Как думать об оптимизации Spark: partitions, shuffle, broadcast, AQE и конфиги

Главная идея: не надо "просто крутить параметры". Сначала нужно понять узкое место: чтение, shuffle, skew, память, количество partitions, маленькие файлы или driver result.

## 1. Как правильно думать об оптимизации

Правильный порядок диагностики:

1. Понять, какая action запускает дорогой job.
2. Открыть Spark UI и найти самый долгий stage.
3. Проверить tasks: их слишком мало, слишком много или один task сильно дольше остальных.
4. Проверить Shuffle Read/Write и spill.
5. Посмотреть SQL plan: есть ли `Exchange`, какой join strategy выбран.
6. Только после этого менять код или параметры.

Плохой подход: увеличить `spark.executor.memory` и надеяться, что всё станет быстрее. Иногда поможет, но часто проблема в shuffle, skew, маленьких файлах или ненужном `collect()`.

## 2. Ресурсы executors

### `spark.executor.instances`

Почему существует: Spark должен знать, сколько executor-процессов получить у cluster manager.

Мало executors - мало суммарных cores и памяти. Слишком много executors - overhead, конкуренция за cluster resources, много сетевого обмена.

### `spark.executor.cores`

Почему существует: один executor может выполнять несколько tasks параллельно.

Мало cores - executor недоиспользует CPU. Слишком много cores на executor - много parallel tasks конкурируют за одну heap-память, что может ухудшить GC и spill.

### `spark.executor.memory`

Почему существует: tasks, shuffle, join, sort, aggregation и cache требуют JVM heap.

Увеличивать стоит, если есть признаки memory pressure: spill, executor OOM, высокий GC. Но если один ключ создаёт огромный skewed partition, простое увеличение памяти может только отложить проблему.

### `spark.executor.memoryOverhead`

Почему существует: executor использует не только JVM heap. PySpark workers, native memory, direct buffers и thread stacks тоже требуют памяти.

Если контейнер убивает YARN/Kubernetes или видно `memory overhead exceeded`, смотрите этот параметр.

## 3. Driver memory

### `spark.driver.memory`

Почему существует: Driver хранит планы, metadata и результаты, возвращённые actions.

Если Driver падает после `collect()` или `toPandas()`, увеличение может помочь только для маленького превышения. Основное исправление - не собирать большой DataFrame на Driver.

### `spark.driver.maxResultSize`

Почему существует: это предохранитель, который ограничивает объём данных, возвращаемых на Driver.

Если ошибка связана с max result size, не надо сразу ставить `0` или огромный лимит. Сначала спросите: почему результат вообще возвращается на Driver?

## 4. Input partitions

### `spark.sql.files.maxPartitionBytes`

Почему существует: при чтении файлов Spark должен решить, сколько байт положить в одну input partition.

Слишком большое значение - мало partitions, крупные tasks, риск OOM. Слишком маленькое - много мелких tasks и overhead.

## 5. Shuffle partitions

### `spark.sql.shuffle.partitions`

Почему существует: после shuffle Spark должен решить, на сколько частей разбить данные.

Мало shuffle partitions:

- большие partitions;
- риск spill/OOM;
- мало parallelism.

Много shuffle partitions:

- много мелких tasks;
- overhead;
- возможны маленькие файлы.

Дефолтные 200 часто плохи для маленьких учебных данных: Spark создаёт 200 маленьких reduce tasks, хотя данных мало.

## 6. AQE

### `spark.sql.adaptive.enabled`

Почему существует: Spark не всегда точно знает размеры данных до выполнения. AQE позволяет менять план на основе runtime statistics.

AQE может:

- coalesce маленькие shuffle partitions;
- менять join strategy;
- помогать со skew join.

### `spark.sql.adaptive.coalescePartitions.enabled`

Почему существует: после shuffle часто получается много маленьких partitions. AQE может объединить их.

### `spark.sql.adaptive.advisoryPartitionSizeInBytes`

Почему существует: Spark нужен ориентир, какой размер post-shuffle partition считать нормальным.

AQE полезен, но не отменяет понимания shuffle. Если код создаёт лишний join или `coalesce(1)`, AQE не сделает архитектурно плохой pipeline хорошим.

## 7. Broadcast join

### `spark.sql.autoBroadcastJoinThreshold`

Почему существует: Spark может автоматически broadcast-ить маленькую таблицу, чтобы избежать shuffle большой таблицы.

Broadcast join хорош, когда одна сторона действительно маленькая и помещается в память executors.

Broadcast может навредить, если:

- таблица не такая маленькая, как кажется;
- у executors мало memory overhead/heap;
- broadcast повторяется много раз;
- статистика неверная и Spark выбрал плохой план.

## 8. Repartition и coalesce

`repartition(n)`:

- меняет количество partitions;
- делает shuffle;
- лучше перераспределяет данные;
- дороже.

`coalesce(n)`:

- обычно уменьшает количество partitions;
- часто дешевле;
- может дать неравномерные partitions.

`coalesce(1)` перед записью - плохая привычка. Она заставляет Spark свести результат к одной partition, один executor пишет один файл, параллелизм исчезает.

## Таблица симптомов

| Симптом | Что смотреть | Что менять |
|---|---|---|
| После groupBy 200 маленьких tasks | Stages -> tasks | `spark.sql.shuffle.partitions`, AQE |
| Executor OOM | logs, spill, GC | `spark.executor.memory`, размер partitions |
| Memory overhead exceeded | container logs | `spark.executor.memoryOverhead` |
| Driver упал | collect/toPandas | `spark.driver.memory`, `spark.driver.maxResultSize`, убрать collect |
| Медленный join | explain: SortMergeJoin/Exchange | broadcast, `autoBroadcastJoinThreshold` |
| Один task сильно дольше | task duration, shuffle read | skew, AQE, salting |
| Много маленьких файлов | output directory | coalesce, repartition |

## Самопроверка

- Почему нельзя просто всегда увеличивать executor.memory?
- Почему дефолтные 200 shuffle partitions плохи для маленьких данных?
- Когда broadcast join может навредить?
- Чем repartition отличается от coalesce?
- Почему AQE не отменяет необходимость понимать shuffle?
