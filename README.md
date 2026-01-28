# Ash
A no-bullshit, seamless way to use LLMs right inside your shell (bash, zsh). Supports OpenAI, Ollama and OpenRouter

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

**Note:** This feature currently doesnt work in fish because of restrictions in the command not found handler

- **Easily extensible**: Simply implement a new provider to use your llm of choice

## Installation
Clone the repository and build the project. Execute the binary and follow on screen instructions for further information. The installer will move the binary into `/usr/local/bin` and append some lines into your shell config

## Configuration
After installation edit the config file found under `~/.config/ash/config.json` to change your provider, choose your model and add your API key
```json
{
    "provider": "enter-your-provider",
    "api_key": "enter-your-api-key",
    "model": "enter-your-model"
}
```
Other important files:
- Chat history: `~/.ash_history.json`

## Dependencies
`"argsd": "1.2.0"`<br>
`"requests": "2.2.0"`
