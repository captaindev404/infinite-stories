//
//  SyncStatusIndicator.swift
//  InfiniteStories
//
//  Created by Claude Code on 28/09/2025.
//

import SwiftUI

// MARK: - Sync Status Indicator

struct SyncStatusIndicator: View {
    @StateObject private var syncService = SyncService.shared
    @State private var showingSyncDetails = false

    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Compact View

    private var compactView: some View {
        Button {
            showingSyncDetails = true
        } label: {
            HStack(spacing: 4) {
                syncIcon
                    .font(.caption)
                    .foregroundColor(syncColor)

                if syncService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if syncService.pendingChangesCount > 0 {
                    Text("\(syncService.pendingChangesCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(syncColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSyncDetails) {
            SyncDetailView()
        }
    }

    // MARK: - Full View

    private var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("Sync Status", systemImage: syncIconName)
                    .font(.headline)
                    .foregroundColor(syncColor)

                Spacer()

                if syncService.isOnline {
                    syncActionButton
                }
            }

            // Status Details
            VStack(alignment: .leading, spacing: 4) {
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if syncService.isSyncing {
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if let lastSync = syncService.lastSyncTime {
                    Text("Last synced \(lastSync, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Simplified - no complex error tracking
            }

            // Pending Changes
            if syncService.pendingChangesCount > 0 {
                pendingChangesView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Subviews

    private var syncIcon: some View {
        Image(systemName: syncIconName)
            .rotationEffect(.degrees(syncService.isSyncing ? 360 : 0))
            .animation(syncService.isSyncing ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: syncService.isSyncing)
    }

    private var syncActionButton: some View {
        Button {
            Task {
                try? await syncService.sync()
            }
        } label: {
            if syncService.isSyncing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing")
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
            }
        }
        .font(.caption)
        .buttonStyle(.borderedProminent)
        .disabled(syncService.isSyncing || !syncService.isOnline)
    }

    // Simplified - removed complex progress and error views

    private var pendingChangesView: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.blue)
                .font(.caption)

            Text("\(syncService.pendingChangesCount) change\(syncService.pendingChangesCount == 1 ? "" : "s") pending")
                .font(.caption)
                .foregroundColor(.blue)

            Spacer()

            if syncService.isOnline && !syncService.isSyncing {
                Button("Sync Now") {
                    Task {
                        try? await syncService.sync()
                    }
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }

    // MARK: - Computed Properties

    private var syncIconName: String {
        if !syncService.isOnline {
            return "wifi.slash"
        } else if syncService.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncService.pendingChangesCount > 0 {
            return "icloud.and.arrow.up"
        } else {
            return "checkmark.icloud"
        }
    }

    private var syncColor: Color {
        if !syncService.isOnline {
            return .gray
        } else if syncService.isSyncing {
            return .orange
        } else if syncService.pendingChangesCount > 0 {
            return .blue
        } else {
            return .green
        }
    }

    private var statusDescription: String {
        if !syncService.isOnline {
            return "Offline"
        } else if syncService.isSyncing {
            return "Syncing..."
        } else if syncService.pendingChangesCount > 0 {
            return "\(syncService.pendingChangesCount) changes pending"
        } else if let lastSync = syncService.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Ready to sync"
        }
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}

// MARK: - Sync Detail View

struct SyncDetailView: View {
    @StateObject private var syncService = SyncService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overall Status
                    overallStatusSection

                    // Connection Status
                    connectionStatusSection

                    // Pending Changes
                    if syncService.pendingChangesCount > 0 {
                        pendingChangesSection
                    }

                    // Sync History
                    syncHistorySection

                    // Simplified - no complex error details

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Sync Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var overallStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Status")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: syncStatusIcon)
                    .font(.title2)
                    .foregroundColor(syncStatusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStatusTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(syncStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if syncService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: syncService.isOnline ? "wifi" : "wifi.slash")
                    .foregroundColor(syncService.isOnline ? .green : .red)

                Text(syncService.isOnline ? "Online" : "Offline")
                    .fontWeight(.medium)

                Spacer()

                if !syncService.isOnline {
                    Text("Changes will sync when online")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var pendingChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Changes")
                    .font(.headline)

                Spacer()

                Text("\(syncService.pendingChangesCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                    .foregroundColor(.blue)
            }

            Text("These changes will be synced when you go online")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    private var syncHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync History")
                .font(.headline)

            if let lastSync = syncService.lastSyncTime {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.green)

                        Text("Last successful sync")
                            .fontWeight(.medium)

                        Spacer()

                        Text(lastSync, formatter: fullDateFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(lastSync, formatter: relativeDateFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            } else {
                Text("No sync history")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
        }
    }

    // Simplified - no complex error tracking

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    try? await syncService.sync()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(syncService.isSyncing ? "Syncing..." : "Sync Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(syncService.isSyncing || !syncService.isOnline)

            // Simplified - single sync action only
        }
    }

    // MARK: - Computed Properties

    private var syncStatusIcon: String {
        if !syncService.isOnline {
            return "wifi.slash"
        } else if syncService.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncService.pendingChangesCount > 0 {
            return "icloud.and.arrow.up"
        } else {
            return "checkmark.icloud.fill"
        }
    }

    private var syncStatusColor: Color {
        if !syncService.isOnline {
            return .gray
        } else if syncService.isSyncing {
            return .orange
        } else if syncService.pendingChangesCount > 0 {
            return .blue
        } else {
            return .green
        }
    }

    private var syncStatusTitle: String {
        if !syncService.isOnline {
            return "Offline"
        } else if syncService.isSyncing {
            return "Syncing"
        } else if syncService.pendingChangesCount > 0 {
            return "Changes Pending"
        } else {
            return "Up to Date"
        }
    }

    private var syncStatusDescription: String {
        if !syncService.isOnline {
            return "Offline"
        } else if syncService.isSyncing {
            return "Syncing..."
        } else if syncService.pendingChangesCount > 0 {
            return "\(syncService.pendingChangesCount) changes pending"
        } else if let lastSync = syncService.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Ready to sync"
        }
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Simplified - removed complex entity sync status views

// MARK: - Preview

struct SyncStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SyncStatusIndicator(compact: true)
            SyncStatusIndicator(compact: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}