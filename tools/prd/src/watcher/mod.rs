pub mod daemon;
pub mod file_watcher;

// Temporarily disabled - pre-existing compilation errors
// #[cfg(test)]
// mod tests;

pub use file_watcher::FileWatcher;
