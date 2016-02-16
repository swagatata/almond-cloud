all:
	git submodule update --init --recursive
	make -C node_modules/thingengine-core all
	make -C node_modules/sabrina all
	cd node_modules/thingpedia ; npm install --no-optional --only=prod
	cd node_modules/thingpedia-client ; npm install --no-optional --only=prod
	cd node_modules/thingpedia-discovery ; npm install --no-optional --only=prod
	cd node_modules/thingpedia-builtins ; npm install --no-optional --only=prod
	cd node_modules/thingtalk ; npm install --no-optional --only=prod
	# remove duplicate copy of thingtalk
	# we cannot rely on npm dedupe because we're playing submodule tricks
	rm -fr node_modules/sabrina/node_modules/thingtalk
	# remove duplicate copy of omclient
	# we cannot rely on npm dedupe because it's a tarball module and it craps itself
	rm -fr node_modules/thingpedia-builtins/node_modules/omclient
	npm install
	npm dedupe

database:
	mysql -u root -p -B -s -e 'show create database thingengine_selfcontained' | grep -q "CREATE DATABASE" || make database-force

database-force:
	mysql -u root -p < model/schema.sql

SUBDIRS = model util public routes views node_modules/
our_sources = main.js frontend.js instance/platform.js instance/runengine.js platform_config.js

# Note the / after engine, forces symlink resolution
install: all
	install -m 0755 -d $(DESTDIR)$(prefix)
	for d in $(SUBDIRS) ; do cp -pr $$d/ $(DESTDIR)$(prefix) ; done
	install -m 0644 $(our_sources) $(DESTDIR)$(prefix)

clean:
	make -C node_modules/thingengine-core clean
	make -C node_modules/sabrina clean

run:
	test -d ./home || mkdir ./home ;
	cd ./home ; node ../main.js
