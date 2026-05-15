FROM bitnamilegacy/spark:3.5

USER root

ENV PATH="/opt/bitnami/python/bin:/opt/bitnami/spark/bin:${PATH}"

RUN python -m pip install --no-cache-dir \
    boto3 \
    jupyter \
    jupyterlab \
    pandas \
    pyspark==3.5.* \
    psycopg2-binary

USER 1001

WORKDIR /app
