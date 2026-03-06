module history;

import std.file;
import std.json;
import std.path;

import std.stdio;
import std.string : format;

JSONValue readHistory()
{
    string wholePath = "~/.ash_history.json".expandTilde;
    if (!exists(wholePath))
    {
        std.file.write(wholePath, "[]");
        return JSONValue();
    }

    return "~/.ash_history.json".expandTilde.readText.parseJSON;
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
