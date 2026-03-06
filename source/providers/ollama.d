module providers.ollama;

import core.thread;
import core.time;
import requests;
import std.concurrency;
import std.json;
import std.stdio;
import std.string;

import history;
import providers.provider;
import spinner;

class OllamaProvider : Provider
{
    private string model;
    private string endpoint;
    private bool showThinking;

    this(string model, bool showThinking, string endpoint)
    {
        this.model = model;
        this.endpoint = endpoint;
        this.showThinking = showThinking;
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
        //body["think"] = true;

        Request rq = Request();
        rq.useStreaming = true;
        rq.keepAlive = true;
        rq.timeout = 600.seconds;
        rq.addHeaders([
            "Content-Type": "application/json"
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

        Response response;
        try
        {
            response = rq.post(endpoint, body.toString());

            if (response.code >= 400)
            {
                spinner.stop();
                writeln("\n\033[31mHTTP Error:\033[0m Received status code ", response.code);

                string errBody;
                foreach (chunk; response.receiveAsRange())
                {
                    errBody ~= cast(string) chunk;
                }
                if (errBody.length > 0)
                {
                    writeln("Details: ", errBody.strip());
                }
                return;
            }
        }
        catch (Exception e)
        {
            spinner.stop();
            writeln("\n\033[31mConnection Error:\033[0m Could not connect to Ollama. Ensure the server is running. (", e
                    .msg, ")");
            return;
        }

        string buffer;
        string fullContent;

        try
        {
            foreach (ubyte[] chunk; response.receiveAsRange())
            {
                buffer ~= cast(string) chunk;
                long idx;

                while ((idx = buffer.indexOf('\n')) != -1)
                {
                    auto line = buffer[0 .. idx].strip();
                    buffer = buffer[idx + 1 .. $];

                    if (line.length == 0)
                        continue;

                    JSONValue parsed;
                    try
                    {
                        parsed = parseJSON(line);

                        if ("error" in parsed)
                        {
                            spinner.stop();
                            writeln("\n\033[31mOllama API Error:\033[0m ", parsed["error"].str);
                            return;
                        }

                        if ("done" in parsed && parsed["done"].type == JSONType.true_)
                            break;

                        if ("message" in parsed)
                        {
                            auto message = parsed["message"];

                            if ("thinking" in message && showThinking)
                            {
                                string thinkText = message["thinking"].str;
                                if (thinkText.length > 0)
                                {
                                    spinner.stop();

                                    if (!isThinkingState)
                                    {
                                        write("\033[90m"); // Gray for thinking
                                        isThinkingState = true;
                                    }

                                    write(thinkText);
                                    stdout.flush();
                                }
                            }

                            if ("content" in message)
                            {
                                string contentText = message["content"].str;
                                if (contentText.length > 0)
                                {
                                    spinner.stop();

                                    if (isThinkingState)
                                    {
                                        write("\033[0m\n"); // Reset color to default for actual response
                                        isThinkingState = false;
                                    }

                                    write(contentText);
                                    stdout.flush();
                                    fullContent ~= contentText;
                                }
                            }
                        }
                    }
                    catch (JSONException)
                    {
                        continue;
                    }
                }
            }
        }
        catch (Exception e)
        {
            spinner.stop();
            writeln("\n\033[31mStream Interrupted:\033[0m Connection to Ollama was lost during generation. (", e.msg, ")");
        }

        writeln();

        if (fullContent.length > 0)
        {
            messages.array ~= JSONValue([
                "role": "assistant",
                "content": fullContent
            ]);

            saveHistory(messages);
        }
    }
}
