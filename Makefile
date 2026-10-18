.PHONY: build init start stop remove remove-all backup update bash bash-run

build:
	docker compose build

init:
	docker compose run --rm --no-deps purpur init

start:
	docker compose up -d

stop:
	docker compose stop

remove:
	docker compose down --remove-orphans

remove-all:
	docker compose down --remove-orphans -v

# Run inside the server container when it is running, so that the backup can
# pause auto-save; otherwise start a one-off container.
backup:
	@if [ -n "$$(docker compose ps -q --status running purpur)" ]; then \
		docker compose exec purpur /entrypoint.sh backup; \
	else \
		docker compose run --rm --no-deps purpur backup; \
	fi

# Start the server again even if the update fails or is cancelled.
update: stop
	-docker compose run --rm --no-deps purpur update
	$(MAKE) start

bash:
	docker compose exec -it purpur /bin/bash

bash-run:
	docker compose run --rm --no-deps purpur /bin/bash
