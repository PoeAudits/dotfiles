# Dotfiles Makefile
.DEFAULT_GOAL := help
.PHONY: help apply diff status update edit env-gen env-check server-status server-restart server-logs

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

apply: ## Apply chezmoi changes
	chezmoi apply

diff: ## Show pending chezmoi changes
	chezmoi diff

status: ## Show chezmoi status
	chezmoi status

update: ## Pull and apply latest dotfiles
	chezmoi update

edit: ## Open chezmoi source directory
	chezmoi cd

env-gen: ## Generate OpenCode server env file from pass
	opencode-env generate

env-check: ## Check OpenCode server env file status
	opencode-env check

server-status: ## Show OpenCode server status
	systemctl status opencode-web

server-restart: ## Restart OpenCode server
	systemctl restart opencode-web

server-logs: ## Follow OpenCode server logs
	journalctl -u opencode-web -f
