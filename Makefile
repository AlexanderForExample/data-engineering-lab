.PHONY: help up down postgres psql hive hive-check jupyter seminar logs

help:
	@printf "Targets: up, down, postgres, psql, hive, hive-check, jupyter, seminar, logs\n"

up:
	docker compose up -d

down:
	docker compose down

postgres:
	docker compose up -d postgres-dwh
	@until docker compose exec postgres-dwh pg_isready -U admin -d dwh >/dev/null 2>&1; do sleep 1; done
	docker compose exec postgres-dwh psql -U admin -d dwh -f /docker-entrypoint-initdb.d/01_lecture_01.sql

psql:
	docker compose exec postgres-dwh psql -U admin -d dwh

hive:
	docker compose up -d namenode datanode hdfs-init hive-metastore-postgresql hive-metastore hive-server
	@until docker compose exec namenode /opt/hadoop-3.2.1/bin/hdfs dfs -ls / >/dev/null 2>&1; do sleep 2; done
	docker compose exec namenode /opt/hadoop-3.2.1/bin/hdfs dfs -mkdir -p /tmp /user/spark /warehouse
	docker compose exec namenode /opt/hadoop-3.2.1/bin/hdfs dfs -chown -R spark:supergroup /user/spark /warehouse
	docker compose exec namenode /opt/hadoop-3.2.1/bin/hdfs dfs -chmod 777 /tmp /user/spark
	docker compose exec namenode /opt/hadoop-3.2.1/bin/hdfs dfs -chmod 1777 /warehouse
	@printf "HDFS UI: http://localhost:9870\n"
	@printf "HiveServer2: jdbc:hive2://localhost:10000\n"

hive-check:
	docker compose exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "CREATE DATABASE IF NOT EXISTS lab_check; SHOW DATABASES;"

jupyter:
	docker compose up -d --build jupyter
	docker compose exec -u root jupyter chmod 777 /spark-local
	@test "$$(docker compose ps --status running --services jupyter)" = "jupyter"
	@printf "JupyterLab: http://localhost:8888\n"
	@printf "Spark UI: http://localhost:4040 while SparkSession is running\n"

seminar: jupyter

logs:
	docker compose logs -f jupyter spark-master spark-worker namenode datanode hive-metastore hive-server
