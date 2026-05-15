.PHONY: help test lint up down postgres psql logs-postgres lecture-01-data lecture-01-init seminar-01-data seminar-01-init seminar-01-solutions

help:
	@printf "Available targets: test, lint, up, down, postgres, psql, logs-postgres, lecture-01-data, lecture-01-init, seminar-01-data, seminar-01-init, seminar-01-solutions\n"

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

lecture-01-data:
	docker compose exec postgres-dwh ls -la /data/lecture_01

lecture-01-init:
	docker compose exec postgres-dwh psql -U admin -d dwh -f /docker-entrypoint-initdb.d/01_lecture_01.sql

seminar-01-data: lecture-01-data

seminar-01-init: lecture-01-init

seminar-01-solutions:
	docker compose exec -T postgres-dwh psql -U admin -d dwh < materials/seminar_01_sql/solutions.sql
