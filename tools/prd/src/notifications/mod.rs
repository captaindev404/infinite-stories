//! Desktop notification system for the PRD tool
//!
//! This module provides desktop notifications for important events during
//! `prd watch` dashboard monitoring, including:
//! - Task completions
//! - Agent errors
//! - Project milestones (25%, 50%, 75%, 100%)
//!
//! Configuration is loaded from `~/.prd/config.toml` with sensible defaults.

pub mod config;
pub mod notifier;

pub use config::NotificationConfig;
pub use notifier::Notifier;
