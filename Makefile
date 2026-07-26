# Feedback loops for the project. `make verify` is what the agent workflow runs.
#
# Tooling is pinned to Lua 5.4 to match the interpreter REAPER embeds — testing
# against a different Lua version would verify behaviour the plugin never runs.
# Rocks live in a project-local .luarocks tree so nothing is installed globally.

BIN   := .luarocks/bin
LUA54 := $(shell brew --prefix lua@5.4 2>/dev/null)

.PHONY: verify syntax test lint check install-deps clean

verify: syntax test lint check

# REAPER is not installed on the dev machine, so adapter code can never be run
# here. Parsing every file under the target interpreter is the last check that
# happens before a build goes to the tester.
syntax:
	@find . -name '*.lua' -not -path './.luarocks/*' -print0 | xargs -0 $(LUA54)/bin/luac5.4 -p
	@echo "Syntax OK"

test:
	@$(BIN)/busted

lint:
	@$(BIN)/luacheck src spec Chord Diagram/chord_diagram_spike.lua

check:
	@rm -rf .luals-log
	@lua-language-server --check src \
		--checklevel=Warning --logpath=.luals-log >/dev/null 2>&1 || true
	@if [ -f .luals-log/check.json ] && \
		[ "$$(tr -d '[:space:]' < .luals-log/check.json)" != "[]" ]; then \
		echo "Type check FAILED:"; cat .luals-log/check.json; exit 1; \
	fi
	@echo "Type check passed"

install-deps:
	luarocks --lua-version=5.4 --lua-dir=$(LUA54) --tree .luarocks install busted
	luarocks --lua-version=5.4 --lua-dir=$(LUA54) --tree .luarocks install luacheck

clean:
	@rm -rf .luals-log
