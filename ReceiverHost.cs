using System;
using System.Diagnostics;
using System.IO;
class ReceiverHost {
    static void Main() {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        using (var log = new StreamWriter(Path.Combine(root, "receiver.log"), false)) {
            log.AutoFlush = true;
            var info = new ProcessStartInfo(Path.Combine(root, "runtime", "uxplay-windows.exe"));
            info.WorkingDirectory = Path.Combine(root, "runtime");
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.RedirectStandardOutput = true;
            info.RedirectStandardError = true;
            if (File.Exists(Path.Combine(root, "runtime", "native-engine.txt"))) {
                info.Arguments = File.ReadAllText(Path.Combine(root, "receiver.args")).Trim();
                info.EnvironmentVariables["GST_PLUGIN_PATH"] = Path.Combine(root, "runtime", "lib", "gstreamer-1.0");
                info.EnvironmentVariables["GST_PLUGIN_SYSTEM_PATH"] = "";
                info.EnvironmentVariables["GST_REGISTRY"] = Path.Combine(root, "runtime", "registry.bin");
                info.EnvironmentVariables["PATH"] = Path.Combine(root, "runtime") + ";" + Environment.GetEnvironmentVariable("PATH");
            }
            info.EnvironmentVariables["GST_DEBUG"] = "2";
            info.EnvironmentVariables["GST_DEBUG_FILE"] = Path.Combine(root, "gstreamer.log");
            using (var process = new Process()) {
                process.StartInfo = info;
                process.OutputDataReceived += (s,e) => { if(e.Data != null) lock(log) log.WriteLine(e.Data); };
                process.ErrorDataReceived += (s,e) => { if(e.Data != null) lock(log) log.WriteLine(e.Data); };
                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                process.WaitForExit();
            }
        }
    }
}
