## PostgreSQL

Для практики используется PostgreSQL в Docker-контейнере.

### Запуск PostgreSQL

```bash
make postgres
```
### Подключиться к консоли 

```bash
make psql
```

### Остановить Posgtres

```bash
make down
```

## HDFS и Hive

Для практики доступен небольшой Docker-кластер: HDFS NameNode, HDFS DataNode, Hive Metastore, HiveServer2 и внутренняя PostgreSQL-база для metastore. Общий Hive/Spark warehouse находится в HDFS по пути `/warehouse`.

### Запуск Hive-кластера

```bash
make hive
```

### Проверка Hive-кластера

```bash
make hive-check
```

Параметры подключения:

- HDFS NameNode UI: `http://localhost:9870`
- HDFS DataNode UI: `http://localhost:9864`
- HDFS внутри Docker: `hdfs://namenode:8020`
- HDFS с хоста: `hdfs://localhost:8020`
- Hive Metastore внутри Docker: `thrift://hive-metastore:9083`
- Hive Metastore с хоста: `thrift://localhost:9083`
- PostgreSQL-база Hive Metastore с хоста: `localhost:15432`, database `metastore`, user `hive`, password `hive`
- HiveServer2 с хоста: `jdbc:hive2://localhost:10000`

PostgreSQL для Hive Metastore опубликован на `15432`, поэтому не конфликтует с `postgres-dwh` на `5432`.

### Работа из Jupyter

Jupyter-контейнер получает настройки HDFS и Hive автоматически.

HDFS через WebHDFS:

```python
import os
from hdfs import InsecureClient

client = InsecureClient(os.environ["HDFS_WEBHDFS_URL"], user="spark")
client.makedirs("/warehouse/from_jupyter")
client.list("/warehouse")
```

Hive через PySpark

```python
import os
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .master(os.environ["SPARK_MASTER_URL"])
    .appName("jupyter-hive")
    .config("hive.metastore.uris", os.environ["HIVE_METASTORE_URI"])
    .enableHiveSupport()
    .getOrCreate()
)

spark.sql("SHOW DATABASES").show()
spark.range(3).write.mode("overwrite").parquet("hdfs://namenode:8020/warehouse/from_jupyter_spark")
```

Локальные файлы из окружения Jupyter доступны Spark через `file:///materials/...`.:

Относительные пути и пути без схемы Spark будет интерпретировать через HDFS, потому что `fs.defaultFS` настроен на `hdfs://namenode:8020`. Для локального чтения указывайте префикс `file://`.

## Jupyter

Запуск JupyterLab вместе с PostgreSQL, MinIO, HDFS, Hive и Spark:

```bash
make jupyter
```

Открыть: `http://localhost:8888`.

Логин, пароль и token не требуются.

Spark application UI доступен на `http://localhost:4040`, пока в notebook запущен `SparkSession`.
