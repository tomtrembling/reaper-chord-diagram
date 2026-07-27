# Feedback loops for the project. `make verify` is what the agent workflow runs.
#
# Tooling is pinned to Lua 5.4 to match the interpreter REAPER embeds — testing
# against a different Lua version would verify behaviour the plugin never runs.
# Rocks live in a project-local .luarocks tree so nothing is installed globally.

BIN   := .luarocks/bin
LUA54 := $(shell brew --prefix lua@5.4 2>/dev/null)

.PHONY: verify syntax test lint check index index-check install-deps clean

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
	@$(BIN)/luacheck src spec "Chord Diagram" ref

check:
	@rm -rf .luals-log
	@lua-language-server --check src \
		--checklevel=Warning --logpath=.luals-log >/dev/null 2>&1 || true
	@if [ -f .luals-log/check.json ] && \
		[ "$$(tr -d '[:space:]' < .luals-log/check.json)" != "[]" ]; then \
		echo "Type check FAILED:"; cat .luals-log/check.json; exit 1; \
	fi
	@echo "Type check passed"

# Regenerate the ReaPack index. Reads COMMITTED state, not the working tree —
# header changes must be committed before they appear in the index. A packaging
# change also needs a `@version` bump, because a version already in the index is
# never rewritten: same version, same entry, new `@provides` ignored.
#
# `--ignore src` keeps the modules from being scanned as packages. It does NOT
# stop them being shipped: `@provides` resolves against the git file list, not
# the package list, which is what lets one package carry the whole src/ tree.
#
# Requires: brew install ruby pandoc && gem install reapack-index
index:
	@PATH="$$(brew --prefix ruby)/bin:$$PATH"; \
	 PATH="$$(gem environment gemdir)/bin:$$PATH"; export PATH; \
	 reapack-index --name 'Chord Diagram' --ignore src --ignore spec \
	   --no-commit --warnings
	@$(MAKE) --no-print-directory index-check

# reapack-index reports a provides conflict, or a provided file that does not
# exist, as a WARNING and then drops the entire package from the index — and
# still exits 0. So the index is checked rather than trusted: a build that
# installs no actions, or actions with no modules to require, must not reach
# the tester looking like a success.
#
# Only the NEWEST version block is checked. Every past version is in the file
# too, and counting across all of them would pass on the strength of history
# while the release being shipped was empty.
index-check:
	@block=$$(awk '/<version name=/ { buf = "" } \
	                              { buf = buf $$0 "\n" } \
	               /<\/version>/   { last = buf } \
	               END             { printf "%s", last }' index.xml); \
	 version=$$(printf '%s' "$$block" | sed -n 's/.*<version name="\([^"]*\)".*/\1/p'); \
	 actions=$$(printf '%s\n' "$$block" | grep -c 'main="main"' || true); \
	 modules=$$(printf '%s\n' "$$block" | grep -c 'file="src/' || true); \
	 if [ "$$actions" -ne 3 ] || [ "$$modules" -lt 2 ]; then \
	   echo "index.xml FAILED at version $$version:"; \
	   echo "  $$actions sources marked as actions (want exactly 3)"; \
	   echo "  $$modules module sources (want the whole src/ tree)"; \
	   echo "  Look for a 'conflicts with' or 'file not found' warning above."; \
	   echo "  If the version is unchanged, that is the bug: reapack-index"; \
	   echo "  never rewrites a version already in the index."; \
	   exit 1; \
	 fi; \
	 echo "index.xml OK — version $$version, $$actions actions, $$modules modules"

install-deps:
	luarocks --lua-version=5.4 --lua-dir=$(LUA54) --tree .luarocks install busted
	luarocks --lua-version=5.4 --lua-dir=$(LUA54) --tree .luarocks install luacheck

clean:
	@rm -rf .luals-log
