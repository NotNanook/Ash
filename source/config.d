module config;

import std.file;
import std.json;
import std.stdio;

void createConfig(string configPath) {
    JSONValue config;
    config["provider"] = "your-provider";
    config["api_key"] = "your-api-key";
    config["model"] = "your-model";
    
    std.file.write(configPath, config.toPrettyString());
}

JSONValue parseConfig(string configPath)
{
    if (exists(configPath))
    {
        string configContent = readText(configPath);
        JSONValue json = parseJSON(configContent);
        if (json.type != JSONType.object)
        {
            throw new Exception("Error during json parsing");
        }

        // TODO: Check if json has correct structure
        if ("provider" in json && "api_key" in json && "model" in json)
        {
            return json;
        }
        else
        {
            throw new Exception("Json has wrong structure");
        }
    }
    else
    {
        throw new Exception("This path does not exist. Please enter a valid config file path");
    }
}
