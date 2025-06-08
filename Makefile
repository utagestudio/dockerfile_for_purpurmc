.PHONY: build init start stop remove remove-all backup update bash bash-run

build:
	docker compose build

init:
	docker compose run --rm purpur init

start:
	docker compose up -d

stop:
	docker compose stop

remove:
	docker compose down --remove-orphans

remove-all:
	docker compose down --remove-orphans -v

backup:
	docker compose run --rm purpur backup

update: stop
	docker compose run --rm purpur update
	$(MAKE) start

bash:
	docker compose exec -it purpur /bin/bash

bash-run:
	docker compose run --rm purpur /bin/bash

bash-logwatcher:
	docker compose run --rm log_watcher /bin/bash