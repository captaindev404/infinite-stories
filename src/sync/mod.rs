mod doc_scanner;
mod reconcile;
mod sync_engine;

#[cfg(test)]
mod tests;

pub use doc_scanner::{parse_completion_doc, scan_completion_docs, CompletionDoc};
pub use reconcile::{reconcile, Inconsistency, ReconcileResult};
pub use sync_engine::{sync_tasks_from_docs, SyncError, SyncResult};
