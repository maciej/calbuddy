PREFIX ?= /usr/local

.PHONY: build install test clean

build:
	swift build -c release

install: build
	cp .build/release/CalBuddy $(PREFIX)/bin/calbuddy

test:
	swift test

clean:
	swift package clean
	rm -rf .build
