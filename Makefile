PREFIX ?= /usr/local
COMPLETIONS_DIR ?= completions
BASH_COMPLETION_DIR ?= $(HOME)/.local/share/bash-completion/completions
ZSH_COMPLETION_DIR ?= $(HOME)/.zsh/completions
FISH_COMPLETION_DIR ?= $(HOME)/.config/fish/completions

.PHONY: build install test clean completions install-completions-local

build:
	swift build -c release

install: build
	cp .build/release/CalBuddy $(PREFIX)/bin/calbuddy

test:
	swift test

completions: build
	mkdir -p $(COMPLETIONS_DIR)
	.build/release/CalBuddy completion bash > $(COMPLETIONS_DIR)/calbuddy.bash
	.build/release/CalBuddy completion zsh > $(COMPLETIONS_DIR)/_calbuddy
	.build/release/CalBuddy completion fish > $(COMPLETIONS_DIR)/calbuddy.fish

install-completions-local: completions
	mkdir -p $(BASH_COMPLETION_DIR) $(ZSH_COMPLETION_DIR) $(FISH_COMPLETION_DIR)
	cp $(COMPLETIONS_DIR)/calbuddy.bash $(BASH_COMPLETION_DIR)/calbuddy
	cp $(COMPLETIONS_DIR)/_calbuddy $(ZSH_COMPLETION_DIR)/_calbuddy
	cp $(COMPLETIONS_DIR)/calbuddy.fish $(FISH_COMPLETION_DIR)/calbuddy.fish

clean:
	swift package clean
	rm -rf .build
