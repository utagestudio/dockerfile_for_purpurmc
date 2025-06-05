build:
	docker compose build

init:
	docker compose run --rm purpur init

start:
	docker compose up -d

stop:
	docker compose stop

remove:
	docker compose down

remove-all:
	docker compose down -v

backup:
	docker compose run --rm purpur backup

update: stop
	docker compose run --rm purpur update
	$(MAKE) start

bash:
	docker compose exec -it purpur /bin/bash

bash-run:
	docker compose run --rm purpur /bin/bash
