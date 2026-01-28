module providers.provider;

import std.json;
import std.stdio;

import providers.openai;
import providers.ollama;

interface Provider
{
    void sendToAPI(
        JSONValue messages,
        string prompt
    );
}

Provider createProvider(JSONValue cfg, bool showThinking)
{
    switch (cfg["provider"].str)
    {
    case "openai":
    case "openrouter":
        return new OpenAIStandardProvider(
            cfg["api_key"].str,
            cfg["model"].str,
            showThinking,
            cfg["provider"].str == "openrouter"
                ? "https://openrouter.ai/api/v1/chat/completions"
                : "https://api.openai.com/v1/chat/completions"
        );
    case "ollama":
        return new OllamaProvider(
            cfg["model"].str,
            showThinking,
            "http://localhost:11434/api/chat"
        );
    case "your-provider":
        writeln("Edit /home/nanook/.config/ash/config.json to choose your provider, model and API key");
        return Provider.init;
    default:
        throw new Exception("Unknown provider");
    }
}
