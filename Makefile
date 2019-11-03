BUNDLE?=	bundle
RUBY?=		ruby

DB_URI?=	sqlite://$(CURDIR)/howvoted.sqlite3

.PHONY: help
help:
	@echo Available targets:
	@echo - cache
	@echo - legislator-cache
	@echo - stylesheets
	@echo - server
	@echo - migrations
	@echo - all
	@echo - console

.PHONY: cache
cache: migrations
	$(BUNDLE) exec $(RUBY) script/build_vote_results.rb --year 2016 --limit 622 --db $(DB_URI)
	$(BUNDLE) exec $(RUBY) script/build_vote_results.rb --year 2017 --limit 710 --db $(DB_URI)
	$(BUNDLE) exec $(RUBY) script/build_vote_results.rb --year 2018 --limit 500 --db $(DB_URI)
	$(BUNDLE) exec $(RUBY) script/build_vote_results.rb --year 2019 --limit 609 --db $(DB_URI)

.PHONY: migrations
migrations:
	$(BUNDLE) exec sequel -E -m migrations  $(DB_URI)

.PHONY: stylesheets
stylesheets: public/css/style.css

public/css/style.css: style.scss
	mkdir -p $(dir $@)
	$(BUNDLE) exec scss $< $@

.PHONY: server
server:
	$(BUNDLE) exec rackup

.PHONY: all
all: migrations cache legislator-cache stylesheets server

.PHONY: console
console:
	DB_URI=$(DB_URI) $(BUNDLE) exec sequel $(DB_URI)
