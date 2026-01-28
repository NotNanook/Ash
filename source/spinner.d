module spinner;

import core.thread;
import std.stdio;
import std.concurrency;

class Spinner
{
    private Tid workerTid;
    private bool running;

    public void start()
    {
        if (this.running)
            return;

        workerTid = spawn(&runWorker);
        this.running = true;
    }

    public void stop()
    {
        if (!this.running)
            return;

        send(workerTid, thisTid, true);

        receiveOnly!bool();

        this.running = false;
    }

    private static void runWorker()
    {
        const string[] frames = [
            "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
        ];
        int i = 0;
        bool canceled = false;
        Tid replyTo;

        stdout.write("\033[?25l");
        stdout.flush();

        try
        {
            while (!canceled)
            {
                receiveTimeout(0.msecs,
                    (Tid sender, bool stop) { canceled = stop; replyTo = sender; }
                );

                if (canceled)
                    break;

                stdout.writef("\r%s", frames[i++ % $]);
                stdout.flush();
                Thread.sleep(100.msecs);
            }
        }
        catch (OwnerTerminated)
        {
        }

        stdout.write("\r\033[2K");
        stdout.flush();

        if (replyTo != Tid.init)
            send(replyTo, true);
    }
}
