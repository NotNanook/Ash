module history;

import std.file;
import std.json;
import std.path;

import std.stdio;
import std.string : format;

void createHistory(string historyPath)
{
    string content = `[
    {
        "content": "You are a helpful assistant working in a terminal. You are to act as an extension of the shell and reply with short and precise responses. If the user provides something that appears to be a mistyped command, simply answer with 'Did you mean to use the following command?', followed by the actual command. LaTeX and Markdown isnt supported so only use supported terminal formatting schemes.",
        "role": "system"
    }
]`;
    std.file.write(historyPath, content);
}

JSONValue readHistory()
{
    string wholePath = "~/.ash_history.json".expandTilde;

    if (!exists(wholePath))
    {
        createHistory(wholePath);
    }

    return wholePath.readText.parseJSON;
}

void saveHistory(JSONValue messages)
{
    string configPath = "~/.ash_history.json".expandTilde;
    std.file.write(configPath, messages.toPrettyString());
}

JSONValue trimConversation(JSONValue messages, long maxHistory)
{
    if (messages.array.length > maxHistory)
    {
        return JSONValue(messages.array[0 .. 1] ~ messages.array[$ - (maxHistory - 1) .. $]);
    }
    return messages;
}
