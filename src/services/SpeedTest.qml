pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

// Runs assets/speedtest.sh (Fast.com) for download then upload and exposes live readings.
// Lives in a singleton so a run survives the dashboard tab being unloaded.
Singleton {
    id: root

    readonly property int phaseSeconds: 6
    // Full-scale latch points for the dials, as in Omarchy's overlay
    readonly property list<int> scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]

    property string phase: "" // "down" | "up" | ""
    readonly property bool running: phase !== ""
    property string iface
    property string error

    property real downloadMbps: NaN // Live reading while running, average once done
    property real uploadMbps: NaN
    property real fullScale: scaleStops[0]
    property date lastRun
    property list<var> history: [] // Newest first: { time, down, up }

    property list<real> samples: []
    property string stderrText

    function start(): void {
        if (running)
            return;
        error = "";
        downloadMbps = NaN;
        uploadMbps = NaN;
        fullScale = scaleStops[0];
        runPhase("down");
    }

    function stop(): void {
        // Clear the phase before killing: onExited would otherwise advance to upload
        phase = "";
        proc.running = false;
    }

    function runPhase(next: string): void {
        phase = next;
        samples = [];
        stderrText = "";
        proc.command = [Quickshell.shellPath("assets/speedtest.sh"), next, String(phaseSeconds)];
        proc.running = true;
    }

    function setReading(value: real): void {
        if (phase === "down")
            downloadMbps = value;
        else if (phase === "up")
            uploadMbps = value;

        for (const scaleStop of scaleStops) {
            if (value <= scaleStop * 0.92) {
                fullScale = Math.max(fullScale, scaleStop);
                return;
            }
        }
        fullScale = scaleStops[scaleStops.length - 1];
    }

    function formatMbps(value: real): string {
        if (isNaN(value))
            return "--";
        return value < 10 ? value.toFixed(1) : Math.round(value).toString();
    }

    // The first second is TCP ramp-up, so leave it out of the result
    function average(): real {
        const steady = samples.length > 1 ? samples.slice(1) : samples;
        return steady.length ? steady.reduce((a, b) => a + b, 0) / steady.length : NaN;
    }

    Process {
        id: proc

        stdout: SplitParser {
            onRead: line => { // qmllint disable signal-handler-parameters
                if (line.startsWith("iface ")) {
                    root.iface = line.slice(6);
                    return;
                }
                const value = parseFloat(line);
                if (isNaN(value) || !root.running)
                    return;
                root.samples = [...root.samples, value];
                root.setReading(value);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.stderrText = text.trim()
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (!root.running)
                return; // Stopped by the user

            if (code !== 0) {
                root.error = root.stderrText || Tr.tr("Speed test failed");
                root.phase = "";
                return;
            }

            if (root.phase === "down") {
                root.downloadMbps = root.average();
                root.runPhase("up");
            } else {
                root.uploadMbps = root.average();
                root.phase = "";
                root.lastRun = new Date();
                root.history = [
                    {
                        time: root.lastRun,
                        down: root.downloadMbps,
                        up: root.uploadMbps
                    },
                    ...root.history].slice(0, 5);
            }
        }
    }
}
