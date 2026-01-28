import core.thread;
import requests;
import std.algorithm;
import std.concurrency;
import std.file;
import std.json;
import std.path;
import std.stdio;
import std.string;

import args;

import config;
import history;
import installer;
import providers.openai;
import providers.provider;

static struct Arguments
{
    @Arg("Prompt to send to the LLM", Optional.yes) string prompt;
    @Arg("Custom config file path", 'c', Optional.yes) string configPath;
    @Arg("If a thinking LLM is used, show the thinking process", 't', Optional.yes) bool showThinking;
}

Arguments getArguments(ref string[] args)
{
    Arguments arguments;
    bool helpWanted = parseArgs(arguments, args);

    if (arguments.prompt.length == 0 && args.length > 1)
    {
        arguments.prompt = args[1];
    }

    if (helpWanted)
    {
        printArgsHelp(arguments, "How to use: ./ash-d <Prompt> [Config File] [Show Thinking]");
    }
    return arguments;
}

int main(string[] args)
{
    auto arguments = getArguments(args);
    string configPath = arguments.configPath
        ? arguments.configPath
        : "~/.config/ash/config.json".expandTilde;

    if (arguments.prompt.length == 0)
    {
        installScript(configPath);
        printFinish(configPath);
        return 0;
    }

    JSONValue messages = readHistory();
    messages = trimConversation(messages, 15);

    JSONValue configJson = parseConfig(configPath);

    Provider provider = createProvider(configJson, arguments.showThinking);
    provider.sendToAPI(messages, arguments.prompt);

    return 0;
}
