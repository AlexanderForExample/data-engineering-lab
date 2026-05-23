.PHONY: help test lint up down postgres psql logs-postgres mysql mysql-cli logs-mysql jupyterhub jupyterhub-check logs-jupyterhub lecture-01-data lecture-01-init seminar-01-data seminar-01-init seminar-01-solutions seminar-02-solutions

help:
	@printf "Available targets: test, lint, up, down, postgres, psql, logs-postgres, mysql, mysql-cli, logs-mysql, jupyterhub, jupyterhub-check, logs-jupyterhub, lecture-01-data, lecture-01-init, seminar-01-data, seminar-01-init, seminar-01-solutions, seminar-02-solutions\n"

test:
	pytest

lint:
	python -m compileall src dags tests

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

logs-postgres:
	docker compose logs -f postgres-dwh

mysql:
	docker compose up -d mysql-source
	@until docker compose exec mysql-source mysqladmin ping -h 127.0.0.1 -u source_user -psource_password --silent >/dev/null 2>&1; do sleep 1; done

mysql-cli:
	docker compose exec mysql-source mysql -u source_user -psource_password source_db

logs-mysql:
	docker compose logs -f mysql-source

jupyterhub:
	docker compose up -d --build postgres-dwh mysql-source minio jupyterhub
	@until docker compose exec jupyterhub python /srv/jupyterhub/check_db_connections.py >/dev/null 2>&1; do sleep 1; done
	@test "$$(docker compose ps --status running --services jupyterhub)" = "jupyterhub"
	@printf "JupyterHub is available at http://localhost:8000\n"

jupyterhub-check:
	docker compose exec jupyterhub python /srv/jupyterhub/check_db_connections.py

logs-jupyterhub:
	docker compose logs -f jupyterhub

lecture-01-data:
	docker compose exec postgres-dwh ls -la /data/lecture_01

lecture-01-init:
	docker compose exec postgres-dwh psql -U admin -d dwh -f /docker-entrypoint-initdb.d/01_lecture_01.sql

seminar-01-data: lecture-01-data

seminar-01-init: lecture-01-init

seminar-01-solutions:
	docker compose exec -T postgres-dwh psql -U admin -d dwh < materials/seminar_01_sql/solutions.sql

seminar-02-solutions:
	docker compose exec -T mysql-source mysql -u source_user -psource_password source_db < materials/seminar_02_mysql_source/solutions.sql
