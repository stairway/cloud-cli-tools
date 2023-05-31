alias py="python3"
alias pyt='python3 -m pytest -s'

# https://code.visualstudio.com/docs/python/debugging#_remote-debugging
alias pyd='python3 -m debugpy --wait-for-client --listen "0.0.0.0:${VSCODE_DEBUGPY_PORT}" "$@"'
