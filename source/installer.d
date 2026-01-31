module installer;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.conv : octal;
import std.typecons : tuple;
import std.process;

import config;

void createHistory(string historyPath) {
    string content = `[
    {
        "content": "You are a helpful assistant working in a terminal. You are to act as an extension of the shell and reply with short and precise responses. If the user provides something that appears to be a mistyped command, simply answer with 'Did you mean to use the following command?', followed by the actual command. LaTeX and Markdown isnt supported so only use supported terminal formatting schemes.",
        "role": "system"
    }
]`;
    std.file.write(historyPath, content);
}

void installScript(string configPath) {
    string configDir = dirName(configPath);
    if (!exists(configDir)) {
        try {
            mkdirRecurse(configDir);
        } catch (Exception e) {
            writeln("Warning: Could not create config directory: ", e.msg);
        }
    }

    if (!exists(configPath)) {
        try {
            createConfig(configPath);
            writeln("Config created at: ", configPath);
        } catch (Exception e) {
            writeln("Warning: Could not create config file: ", e.msg);
        }
    }

    string historyPath = expandTilde("~/.ash_history.json");
    if (!exists(historyPath)) {
        try {
            createHistory(historyPath);
            writeln("History file created at: ", historyPath);
        } catch (Exception e) {
            writeln("Warning: Could not create history file: ", e.msg);
        }
    }

    string destPath = "/usr/local/bin/ash";
    writeln("Installing binary to /usr/local/bin (requires sudo)...");
    string installCmd = format("sudo install -m 755 %s %s", thisExePath(), destPath);
    auto pid = spawnShell(installCmd);
    if (wait(pid) != 0) {
        writeln("Error: Failed to install binary. Sudo permission denied or cancelled.");
        return; 
    }

    string bashHook = format(`
# ash
command_not_found_handle() {
    if [ ! -t 0 ]; then
        data=$(cat)
        "%s" "Data: $data Prompt: $*"
    else
        "%s" "$*"
    fi
    return 0
}`, destPath, destPath);

    string zshHook = bashHook.replace("command_not_found_handle", "command_not_found_handler");

    string fishHook = format(`
# ash
function fish_command_not_found
    "%s" "$argv"
end`, destPath);

    auto targets = [
        tuple("Bash", "~/.bashrc", bashHook),
        tuple("Zsh", "~/.zshrc", zshHook),
        tuple("Fish", "~/.config/fish/config.fish", fishHook)
    ];

    foreach (t; targets) {
        string path = expandTilde(t[1]);
        
        if (!exists(dirName(path)) && t[0] == "Fish") continue;

        if (exists(path)) {
            string content = readText(path);
            if (canFind(content, "# ash")) {
                writeln(t[0], ": Hook already installed. Skipping.");
                continue;
            }

            writef("Install for %s? [y/N] ", t[0]);
            string input = readln().strip().toLower();
            if (input == "y") {
                append(path, "\n" ~ t[2] ~ "\n");
                writeln("Installed.");
            }
        }
    }
}

void printFinish(string configPath) {
    enum GREEN = "\033[1;32m";
    enum BLUE = "\033[1;34m";
    enum NC = "\033[0m";

    writeln(GREEN, "╔═══════════════════════════════════════╗", NC);
    writeln(GREEN, "║          Installation Complete        ║", NC);
    writeln(GREEN, "╚═══════════════════════════════════════╝", NC);
    writeln();

    writefln("%sNext steps:%s", BLUE, NC);
    writeln("  1. Edit ", configPath, " to choose your provider, model and API key");
    writeln("  2. Restart your shell");
    writeln("  3. Try typing an unknown command to test ash");
}