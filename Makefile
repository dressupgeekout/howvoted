BUNDLE?=	bundle
RUBY?=		ruby

.PHONY: help
help:
	@echo Available targets:
	@echo - cache
	@echo - legislator-cache
	@echo - stylesheets
	@echo - server
	@echo - all

.PHONY: cache
cache:
	$(BUNDLE) exec $(RUBY) lib/vote_result.rb --year 2016 --limit 622
	$(BUNDLE) exec $(RUBY) lib/vote_result.rb --year 2017 --limit 710
	$(BUNDLE) exec $(RUBY) lib/vote_result.rb --year 2018 --limit 500
	$(BUNDLE) exec $(RUBY) lib/vote_result.rb --year 2019 --limit 609

.PHONY: legislator-cache
legislator-cache:
	$(BUNDLE) exec $(RUBY) lib/legislator.rb 2016

.PHONY: stylesheets
stylesheets: public/css/style.css

public/css/style.css: style.scss
	mkdir -p $(dir $@)
	$(BUNDLE) exec scss $< $@

.PHONY: server
server:
	$(BUNDLE) exec rackup

.PHONY: all
all: cache legislator-cache stylesheets server
