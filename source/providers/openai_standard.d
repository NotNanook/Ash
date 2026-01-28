module providers.openai;

import core.thread;
import requests;
import std.concurrency;
import std.json;
import std.stdio;
import std.string;

import history;
import providers.provider;
import spinner;

class OpenAIStandardProvider : Provider
{
    private string apiKey;
    private string model;
    private bool showThinking;
    private string endpoint;

    this(string apiKey, string model, bool showThinking, string endpoint)
    {
        this.apiKey = apiKey;
        this.model = model;
        this.showThinking = showThinking;
        this.endpoint = endpoint;
    }

    override void sendToAPI(JSONValue messages, string prompt)
    {
        messages.array ~= JSONValue([
            "role": "user",
            "content": prompt
        ]);

        JSONValue body = JSONValue();
        body["model"] = model;
        body["stream"] = true;
        body["messages"] = messages;

        Request rq = Request();
        rq.useStreaming = true;
        rq.addHeaders([
            "Content-Type": "application/json",
            "Authorization": "Bearer " ~ apiKey
        ]);

        Spinner spinner = new Spinner();
        spinner.start();

        bool isThinkingState = false;

        scope (exit)
        {
            spinner.stop();
            if (isThinkingState)
            {
                stdout.write("\033[0m");
            }
            stdout.write("\033[?25h");
            stdout.flush();
        }

        auto response = rq.post(endpoint, body.toString());

        string buffer;
        string fullContent;

        foreach (ubyte[] chunk; response.receiveAsRange())
        {
            buffer ~= cast(string) chunk;
            long idx;

            while ((idx = buffer.indexOf('\n')) != -1)
            {
                auto line = buffer[0 .. idx].strip();
                buffer = buffer[idx + 1 .. $];

                if (!line.startsWith("data: "))
                    continue;

                auto data = line[6 .. $];
                if (data == "[DONE]")
                    break;

                JSONValue parsed;
                try
                {
                    parsed = parseJSON(data);
                    auto delta = parsed["choices"][0]["delta"];

                    if ("reasoning" in delta && showThinking)
                    {
                        string reasoningText = delta["reasoning"].str;
                        if (reasoningText.length > 0)
                        {
                            spinner.stop();

                            if (!isThinkingState)
                            {
                                write("\033[90m");
                                isThinkingState = true;
                            }

                            write(reasoningText);
                            stdout.flush();
                        }
                    }

                    if ("content" in delta)
                    {
                        string text = delta["content"].str;
                        if (text.length > 0)
                        {
                            spinner.stop();
                            if (isThinkingState)
                            {
                                write("\033[0m\n");
                                isThinkingState = false;
                            }

                            write(text);
                            stdout.flush();
                            fullContent ~= text;
                        }
                    }
                }
                catch (JSONException)
                {
                    continue;
                }
            }
        }

        writeln();

        messages.array ~= JSONValue([
            "role": "assistant",
            "content": fullContent
        ]);

        saveHistory(messages);
    }
}
