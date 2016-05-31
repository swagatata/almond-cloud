prefix ?= /opt/thingengine
localstatedir ?= /srv/thingengine

SUBMODULE_DEPS = thingengine-core sabrina thingpedia thingpedia-discovery thingtalk

all: $(SUBMODULE_DEPS) platform_config.js
	make -C sandbox prefix=$(prefix) localstatedir=$(localstatedir) all
	npm install --only=prod
	npm dedupe
	make database

database:
	mysql -u root -p -B -s -e 'show create database thingengine_selfcontained' | grep -q "CREATE DATABASE" || make database-force

database-force:
	mysql -u root -p < model/schema.sql

.PHONY: $(SUBMODULE_DEPS)

$(SUBMODULE_DEPS):
	cd node_modules/$(notdir $@) ; npm install --only=prod

platform_config.js:
	echo "exports.PKGLIBDIR = '$(prefix)'; exports.LOCALSTATEDIR = '$(localstatedir)';" > platform_config.js
