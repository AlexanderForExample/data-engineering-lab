# Архитектура Spark: зачем нужны Driver, Executors и Cluster Manager

Главная идея: Spark-приложение - это не один процесс, а набор процессов. Обычно есть Driver, есть Executors, а ресурсы для них выделяет Cluster Manager.

## Почему одной машины становится мало

Пока данные маленькие, можно загрузить CSV в pandas и обработать его в одном процессе. Но в инженерных задачах быстро появляются проблемы:

- данных больше, чем RAM одной машины;
- чтение с диска занимает слишком много времени;
- одна CPU не успевает обработать все строки;
- нужно выполнять join, groupBy и сортировки над десятками или сотнями гигабайт;
- один сбой машины не должен ломать всю обработку.

Spark решает это распределением работы: данные разбиваются на части, а эти части обрабатываются параллельно на нескольких процессах и машинах.

## Что такое Spark Application

Spark Application - это пользовательская программа на Spark. Она состоит из Driver и Executors. В PySpark вы пишете Python-код, но Spark engine внутри в значительной степени работает в JVM.

Application живёт не только в вашем notebook. Когда вы создаёте `SparkSession`, поднимается SparkContext, который связывает ваш код с распределённым исполнением.

## Driver

Driver - координатор приложения. Он:

- хранит SparkContext и SparkSession;
- принимает ваш код DataFrame API или SQL;
- строит logical и physical plan;
- разбивает выполнение на jobs, stages и tasks;
- отправляет tasks executors;
- собирает метаданные о выполнении;
- показывает Spark UI.

Driver не должен быть местом, куда приезжают все данные. Его задача - управлять, а не выполнять всю тяжёлую обработку.

## Executors

Executors - рабочие процессы Spark. Они:

- выполняют tasks;
- читают partitions данных;
- выполняют filter, join, aggregation, sort;
- хранят cache/persist blocks;
- пишут и читают shuffle blocks;
- отчитываются Driver о результате выполнения.

В кластере у одного приложения обычно несколько executors. Каждый executor может выполнять несколько tasks параллельно, если у него несколько cores.

## Cluster Manager

Cluster Manager выделяет ресурсы. Это может быть Spark Standalone, YARN, Kubernetes или другой менеджер. Он не оптимизирует ваш SQL и не решает, где нужен shuffle. Его задача проще: выдать приложению процессы и ресурсы.

## Схема Spark cluster

![Spark cluster components](https://spark.apache.org/docs/latest/img/cluster-overview.png)

Источник: Apache Spark Documentation, Cluster Mode Overview: https://spark.apache.org/docs/latest/cluster-overview.html

Что важно на этой схеме:

1. Driver - координатор, а не рабочий процесс для всех данных.
2. Executors выполняют tasks.
3. Cluster Manager выделяет ресурсы.
4. Данные обрабатываются распределённо.

## Как Driver отправляет задачи Executors

Когда вы вызываете action, например `count()` или `write.parquet(...)`, Driver строит план выполнения. Затем он делит работу на tasks. Каждая task обычно работает с одной partition данных. Driver отправляет tasks на executors, executors выполняют работу и возвращают Driver только служебную информацию или небольшой результат.

Упрощённо:

```text
Ваш код
  -> SparkSession / SparkContext на Driver
  -> physical plan
  -> jobs
  -> stages
  -> tasks
  -> executors
```

## Почему Driver не должен обрабатывать все данные

Если Driver начнёт собирать весь DataFrame к себе, Spark теряет смысл распределённой обработки. Executors могут обработать терабайты по частям, но Driver часто имеет ограниченную память. Поэтому операции, возвращающие все строки на Driver, опасны.

Особенно опасны:

- `collect()`;
- `toPandas()`;
- `show()` на очень широких данных и с большим `n`;
- циклы, где вы много раз забираете данные на Driver.

`collect()` говорит Spark: "привези все строки результата в процесс Driver". Если результат большой, Driver может упасть по OutOfMemoryError или превысить `spark.driver.maxResultSize`.

## Самопроверка

- Почему Spark-приложение состоит из driver и executors?
- Почему driver нельзя воспринимать как "главный executor"?
- Что делает cluster manager?
- Что произойдёт, если вызвать `collect()` на большом DataFrame?
