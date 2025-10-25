.PHONY: help test install-bin

# Default target - show help
help: ## Show this help message
	@echo "Available targets:"
	@echo ""
	@echo "  \033[36mhelp\033[0m                 Show this help message"
	@echo "  \033[36mtest [command]\033[0m       Run tests (see test commands below)"
	@echo "  \033[36mtest-<name>\033[0m          Run specific test file (e.g., test-paws)"
	@echo "  \033[36minstall-bin\033[0m          Install scripts from ./bin/ to ~/bin/"
	@echo ""
	@echo "Test commands:"
	@echo "  \033[36mtest\033[0m                 Run all tests (default)"
	@echo "  \033[36mtest all\033[0m             Run all tests"
	@echo "  \033[36mtest find\033[0m            Interactive test selection (requires fzf)"
	@echo "  \033[36mtest list\033[0m            List all available test files"
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Run all tests"
	@echo "  make test find         # Interactive test picker"
	@echo "  make test list         # List available tests"
	@echo "  make test-paws         # Run paws tests"
	@echo "  make test-pdetect      # Run pdetect tests"
	@echo "  make install-bin       # Install scripts to ~/bin/"

# Test namespace - handles subcommands
test:
	@case "$(filter-out test,$(MAKECMDGOALS))" in \
		""|all) \
			echo "Running all tests..."; \
			shellspec ;; \
		find) \
			if ! command -v fzf >/dev/null 2>&1; then \
				echo "Error: fzf is not installed"; \
				echo "Install with: brew install fzf"; \
				exit 1; \
			fi; \
			spec=$$(find spec -name '*_spec.sh' -type f | \
				sed 's|spec/||; s|_spec.sh||' | \
				fzf --prompt="Select test to run: " \
				    --height=40% \
				    --border \
				    --preview='echo "Test: {}\nFile: spec/{}_spec.sh"' \
				    --preview-window=up:3:wrap); \
			if [ -n "$$spec" ]; then \
				echo "Running $$spec tests..."; \
				shellspec "spec/$${spec}_spec.sh" -f d; \
			else \
				echo "No test selected"; \
			fi ;; \
		list) \
			echo "Available test files:"; \
			find spec -name '*_spec.sh' -type f | sed 's|spec/||; s|_spec.sh||' | sed 's/^/  - /' ;; \
		*) \
			echo "Unknown test command: $(filter-out test,$(MAKECMDGOALS))"; \
			echo ""; \
			echo "Available commands: all, find, list"; \
			echo "Run 'make help' for more information"; \
			exit 1 ;; \
	esac

# Catch subcommands as targets to prevent "No rule" errors
# When used with 'test', do nothing. When used alone, show error.
all find list:
	@if echo "$(MAKECMDGOALS)" | grep -q "^test"; then \
		: ; \
	else \
		echo "Error: '$@' must be used with the 'test' command"; \
		echo ""; \
		echo "Usage: make test $@"; \
		echo ""; \
		echo "Run 'make help' for more information"; \
		exit 1; \
	fi

# Pattern rule for test-<name> - runs specific test file
test-%:
	@if [ ! -f "spec/$*_spec.sh" ]; then \
		echo "Error: Test file 'spec/$*_spec.sh' not found"; \
		echo ""; \
		echo "Available tests:"; \
		find spec -name '*_spec.sh' -type f | sed 's|spec/||; s|_spec.sh||' | sed 's/^/  - /'; \
		exit 1; \
	fi
	@echo "Running $* tests..."
	@shellspec "spec/$*_spec.sh" -f d

# Install scripts to ~/bin/
install-bin:
	@echo "Installing scripts from ./bin/ to ~/bin/..."
	@mkdir -p ~/bin
	@cp -f bin/* ~/bin/
	@echo "✓ Installation complete"
	@echo ""
	@echo "Installed scripts:"
	@ls -1 bin/p* | sed 's|.*/||' | sed 's/^/  - /'

# Catch-all for unknown targets - show help
%:
	@echo "Error: Unknown target '$@'"
	@echo ""
	@$(MAKE) help

.DEFAULT_GOAL := help
