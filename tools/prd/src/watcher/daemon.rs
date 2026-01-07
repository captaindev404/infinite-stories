use anyhow::Result;
use std::fs;
use std::path::{Path, PathBuf};

const PID_FILE: &str = "/tmp/prd-watcher.pid";
const LOG_FILE: &str = "/tmp/prd-watcher.log";

/// Start the watcher as a daemon process
pub fn start_daemon(docs_path: PathBuf, db_path: PathBuf) -> Result<()> {
    // Check if already running
    if is_running()? {
        return Err(anyhow::anyhow!(
            "File watcher already running (PID file exists)"
        ));
    }

    #[cfg(unix)]
    {
        use std::process::{Command, Stdio};

        // Get current executable path
        let exe_path = std::env::current_exe()?;

        // Spawn background process
        let child = Command::new(exe_path)
            .arg("watch-files")
            .arg("--docs-path")
            .arg(&docs_path)
            .arg("--daemon-mode")
            .stdin(Stdio::null())
            .stdout(Stdio::from(fs::File::create(LOG_FILE)?))
            .stderr(Stdio::from(
                fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(LOG_FILE)?,
            ))
            .spawn()?;

        // Write PID file
        fs::write(PID_FILE, child.id().to_string())?;

        println!("✓ File watcher started in background (PID: {})", child.id());
        println!("  Logs: {}", LOG_FILE);
        println!("  Use 'prd watch-files --status' to check status");
        println!("  Use 'prd watch-files --stop' to stop");

        Ok(())
    }

    #[cfg(not(unix))]
    {
        Err(anyhow::anyhow!(
            "Daemon mode only supported on Unix systems"
        ))
    }
}

/// Stop the daemon process
pub fn stop_daemon() -> Result<()> {
    if !is_running()? {
        return Err(anyhow::anyhow!("File watcher not running"));
    }

    let pid_str = fs::read_to_string(PID_FILE)?;
    let pid = pid_str.trim().parse::<i32>()?;

    #[cfg(unix)]
    {
        use nix::sys::signal::{kill, Signal};
        use nix::unistd::Pid;

        // Send SIGTERM
        kill(Pid::from_raw(pid), Signal::SIGTERM)?;

        // Wait a bit for graceful shutdown
        std::thread::sleep(std::time::Duration::from_secs(1));

        // Remove PID file
        let _ = fs::remove_file(PID_FILE);

        println!("✓ File watcher stopped");
        Ok(())
    }

    #[cfg(not(unix))]
    {
        Err(anyhow::anyhow!(
            "Daemon mode only supported on Unix systems"
        ))
    }
}

/// Check the status of the daemon
pub fn status() -> Result<()> {
    if !is_running()? {
        println!("File watcher: Not running");
        return Ok(());
    }

    let pid_str = fs::read_to_string(PID_FILE)?;
    let pid = pid_str.trim();

    println!("File watcher: Running (PID {})", pid);
    println!("Logs: {}", LOG_FILE);

    // Try to show tail of log
    if Path::new(LOG_FILE).exists() {
        println!("\nRecent log entries:");
        let _ = std::process::Command::new("tail")
            .args(&["-n", "5", LOG_FILE])
            .status();
    }

    Ok(())
}

/// Check if the daemon is running
fn is_running() -> Result<bool> {
    if !Path::new(PID_FILE).exists() {
        return Ok(false);
    }

    let pid_str = fs::read_to_string(PID_FILE)?;
    let pid = pid_str.trim().parse::<i32>()?;

    #[cfg(unix)]
    {
        use nix::sys::signal::kill;
        use nix::unistd::Pid;

        // Check if process exists (signal 0 doesn't kill)
        match kill(Pid::from_raw(pid), None) {
            Ok(_) => Ok(true),
            Err(_) => {
                // Process doesn't exist, clean up PID file
                let _ = fs::remove_file(PID_FILE);
                Ok(false)
            }
        }
    }

    #[cfg(not(unix))]
    {
        // On Windows, just check if PID file exists
        Ok(true)
    }
}
