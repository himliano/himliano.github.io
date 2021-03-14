.DEFAULT_GOAL := build

build:
	@bundle exec jekyll build

serve:
	@bundle exec jekyll serve