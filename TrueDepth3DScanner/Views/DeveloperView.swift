import SwiftUI

/// Developer/Debug tab displaying all captured log entries.
/// Provides "Copy All Logs" and "Clear Logs" actions for AI-assisted debugging.
struct DeveloperView: View {
    @StateObject private var viewModel = DeveloperViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats bar
                statsBar

                Divider()
                    .background(.gray.opacity(0.3))

                // Log list
                if viewModel.logger.entries.isEmpty {
                    emptyStateView
                } else {
                    logListView
                }
            }
            .background(Color.black)
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.copyLogs()
                        } label: {
                            Label("Copy All Logs", systemImage: "doc.on.clipboard")
                        }

                        Button(role: .destructive) {
                            viewModel.clearLogs()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 20) {
            statBadge(
                count: viewModel.logger.entries.filter { $0.level == .error }.count,
                label: "Errors",
                color: .red
            )
            statBadge(
                count: viewModel.logger.entries.filter { $0.level == .warning }.count,
                label: "Warnings",
                color: .orange
            )
            statBadge(
                count: viewModel.logger.entries.count,
                label: "Total",
                color: .cyan
            )

            Spacer()

            Button {
                viewModel.copyLogs()
            } label: {
                Label("Copy All", systemImage: "doc.on.clipboard.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.cyan.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Log List

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.logger.entries) { entry in
                        logEntryRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.logger.entries.count) { _, _ in
                if let lastEntry = viewModel.logger.entries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logEntryRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(entry.formatted)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(colorForLevel(entry.level))
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .info:    return .white.opacity(0.85)
        case .warning: return .orange
        case .error:   return .red
        case .debug:   return .cyan.opacity(0.7)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.alignleft")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.4))
            Text("No Logs")
                .font(.title3)
                .foregroundStyle(.gray)
            Text("Log entries will appear here as\nthe app runs and scans faces.")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}
