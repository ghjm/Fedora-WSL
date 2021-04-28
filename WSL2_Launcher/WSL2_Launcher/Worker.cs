using System;
using System.Collections.Generic;
using System.Text;
using System.ComponentModel;
using System.Net;
using System.Net.NetworkInformation;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
using System.Runtime;

namespace WSL2_Launcher
{
    class Worker : BackgroundWorker
    {
        // Main form
        Form1 form1;

        public Worker()
        {
            this.WorkerReportsProgress = true;
            this.form1 = new Form1();
            _ = this.form1.Handle;
            this.ProgressChanged += this.form1.backgroundWorker_ProgressChanged;
        }

        public void ShowProgress(string message)
        {
            this.ReportProgress(0, message);
            Console.WriteLine(message);
        }

        public delegate void ShowFormDelegate();

        protected override void OnDoWork(DoWorkEventArgs e)
        {
            base.OnDoWork(e);

            // Set up delayed main form load if the process takes a while
            new Thread(() =>
            {
                Thread.CurrentThread.IsBackground = true;
                Thread.Sleep(500);
                this.form1.BeginInvoke(new ShowFormDelegate(this.form1.Show));
            }).Start();

            // Check if there is an X server running
            this.ShowProgress("Checking X server");
            var ip_props = IPGlobalProperties.GetIPGlobalProperties();
            var endpoints = ip_props.GetActiveTcpListeners();
            bool found = false;
            foreach (var endpoint in endpoints)
            {
                if (endpoint.Port == 6000)
                {
                    found = true;
                    break;
                }
            }
            if (!found)
            {
                this.ShowProgress("Starting X server");
                Process.Start("C:\\Program Files\\Xming\\Xming.exe", ":0 -clipboard -multiwindow");
            }

            // Get IP address and gateway of WSL2 session
            this.ShowProgress("Getting WSL2 networking information");
            var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = Environment.GetEnvironmentVariable("WINDIR") + "\\System32\\wsl.exe",
                    Arguments = "bash -c \"ip -4 route | grep default | cut -d ' ' -f 3; ip -4 addr show eth0 | grep inet | cut -d ' ' -f 6 | sed 's/\\/.*//'\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            string output = proc.StandardOutput.ReadToEnd();
            var outlines = output.Split(new[] { "\r\n", "\n", "\r" }, StringSplitOptions.RemoveEmptyEntries);
            if (outlines.Length != 2) {
                throw new ApplicationException("Incorrect network information returned from WSL");
            }
            var gateway = outlines[0];
            var ipaddr = outlines[1];

            // Authorize the X server
            this.ShowProgress("Authorizing X server");
            proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = Environment.GetEnvironmentVariable("COMSPEC"),
                    Arguments = $"/c set DISPLAY=127.0.0.1:0& \"C:\\Program Files\\Xming\\xhost.exe\" +{ipaddr}",
                    UseShellExecute = false,
                    RedirectStandardOutput = false,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            proc.WaitForExit();

            // Run requested command, or xlunch
            string command;
            var cli = Environment.GetCommandLineArgs();
            if (cli.Length > 1)
            {
                command = cli[1];
            }
            else
            {
                command = "~/bin/xlunch --multiple";
            }
            this.ShowProgress($"Launching {command}");
            proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = Environment.GetEnvironmentVariable("COMSPEC"),
                    Arguments = $"/c wsl DISPLAY={gateway}:0 {command}",
                    UseShellExecute = false,
                    RedirectStandardOutput = false,
                    CreateNoWindow = true
                }
            };
            proc.Start();

            // Finish and exit
            this.ReportProgress(100, "Done");
            Application.Exit();
        }
    }
}
