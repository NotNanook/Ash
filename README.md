# Ash
A no-bullshit, seamless way to use LLMs right inside your shell (bash, zsh). Supports OpenAI, Claude and Ollama

## Why?

Ever felt that most AI tools sound nice but are completely impractical or simply useless? Then try Ash, because you don’t need another bloated wrapper or half-baked CLI tool.

## Features

- **Command-not-found Fallback**: Unrecognized commands become AI queries

```
~ ❯ hey chat how are you
I'm a program — ready to help. What would you like to do?
```
```python
~ ❯ ls
Desktop/  Documents/  Downloads/  Music/  Pictures/  Videos/
```

- **Shell Integration**: Respects redirections, pipes, and standard shell behavior

```sh
git log --oneline -10 | summarize recent changes
grep "ERROR" app.log | categorize these errors > error_types.txt
```

- **Easily extensible**: Simply implement a new `__send_to` function to `ash.zsh`. Feel free to create pull request

## Installation
Clone the repository and use the installer file. Follow on screen instructions for further information. The installer will append the following lines into your config file (zsh)
```zsh
# BEGIN ash
if [[ -f "/home/user/.config/ash/ash.zsh" ]]; then
    source "/home/user/.config/ash/ash.zsh"
fi
# END ash
```

## Dependencies
`jq`
`curl`

## Configuration
Ash file: `~/.config/ash/ash.zsh` or `~/.config/ash/ash.sh`<br>
Config file: `~/.config/ash/config.json`<br>
Chat history: `~/.config/ash/conversation.json`<br>
History limit: 15 messages (configurable via MAX_HISTORY in script)<br>
