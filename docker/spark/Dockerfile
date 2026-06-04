FROM bitnamilegacy/spark:3.5

USER root

ENV PATH="/opt/bitnami/python/bin:/opt/bitnami/spark/bin:/usr/local/bin:${PATH}"
ENV HADOOP_CONF_DIR="/opt/bitnami/spark/conf"
ENV SPARK_CONF_DIR="/opt/bitnami/spark/conf"

RUN python -m pip install --no-cache-dir \
    boto3 \
    hdfs \
    jupyter \
    jupyterlab \
    pandas \
    pyhive \
    pyspark==3.5.* \
    psycopg2-binary \
    thrift \
    thrift_sasl \
    pure-sasl

COPY conf/core-site.xml /opt/bitnami/spark/conf/core-site.xml
COPY conf/hdfs-site.xml /opt/bitnami/spark/conf/hdfs-site.xml
COPY conf/hive-site.xml /opt/bitnami/spark/conf/hive-site.xml
COPY conf/spark-defaults.conf /opt/bitnami/spark/conf/spark-defaults.conf
COPY bin/hdfs /usr/local/bin/hdfs

RUN chmod +x /usr/local/bin/hdfs && \
    ln -sf /opt/bitnami/python/bin/python /usr/local/bin/python && \
    ln -sf /opt/bitnami/python/bin/python3 /usr/local/bin/python3

RUN if ! getent group supergroup >/dev/null; then \
      printf 'supergroup:x:1001:\n' >> /etc/group; \
    fi && \
    if ! getent passwd 1001 >/dev/null; then \
      printf 'spark:x:1001:1001:Spark User:/tmp:/bin/bash\n' >> /etc/passwd; \
    fi

USER 1001

WORKDIR /app
