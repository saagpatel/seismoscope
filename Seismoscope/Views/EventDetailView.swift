import SwiftUI
import SwiftData

/// Sheet shown when user taps an event annotation on the ribbon.
/// Fetches the matching SeismicEvent from the SwiftData store by UUID.
struct EventDetailView: View {
    let eventId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var event: SeismicEvent?

    var body: some View {
        NavigationStack {
            Group {
                if let event {
                    eventContent(event)
                } else {
                    ContentUnavailableView("Event Not Found", systemImage: "waveform.path")
                }
            }
            .navigationTitle("Event Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .background(.ultraThinMaterial)
        .onAppear { loadEvent() }
    }

    // MARK: - Content

    @ViewBuilder
    private func eventContent(_ event: SeismicEvent) -> some View {
        List {
            // Correlation status badge
            Section {
                statusRow(for: event)
            }

            // Detection data
            Section("Detection") {
                detailRow("Onset", value: event.onsetTime.formatted(date: .complete, time: .standard))
                if event.duration > 0 {
                    detailRow("Duration", value: String(format: "%.1f seconds", event.duration))
                }
                detailRow("Peak", value: String(format: "%.1f mg", event.peakAcceleration))
                detailRow("Dominant Axis", value: event.dominantAxis.uppercased() + " axis")
                detailRow("STA/LTA Ratio", value: String(format: "%.1f×", event.staLtaRatio))
            }

            // USGS section — only when matched
            if event.correlationStatus == "matched" {
                usgsSection(event)
            }
        }
        .listStyle(.insetGrouped)
        .font(.system(.body, design: .monospaced))
    }

    @ViewBuilder
    private func statusRow(for event: SeismicEvent) -> some View {
        switch event.correlationStatus {
        case "pending":
            HStack {
                ProgressView().scaleEffect(0.8)
                Text("Checking USGS earthquake catalog…")
                    .foregroundStyle(.secondary)
            }
        case "matched":
            Label("Earthquake matched", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.red)
        case "local":
            Label("No earthquake match found", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        case "timeout":
            Label("No match found (checked \(event.retryCount) times)", systemImage: "clock.badge.xmark")
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func usgsSection(_ event: SeismicEvent) -> some View {
        Section("USGS Earthquake Data") {
            if let mag = event.usgsMagnitude {
                detailRow("Magnitude", value: String(format: "M%.1f", mag))
            }
            if let place = event.usgsPlace {
                detailRow("Location", value: place)
            }
            if let depth = event.usgsDepthKm {
                detailRow("Depth", value: String(format: "%.1f km", depth))
            }
            if let dist = event.usgsDistanceKm {
                detailRow("Distance", value: String(format: "%.0f km away", dist))
            }
            if let originTime = event.usgsOriginTime {
                detailRow("Origin Time", value: originTime.formatted(date: .omitted, time: .standard))
            }
            if let urlString = event.usgsEventURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    Label("View on USGS", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
        }
    }

    // MARK: - Data

    private func loadEvent() {
        let descriptor = FetchDescriptor<SeismicEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        event = try? modelContext.fetch(descriptor).first
    }
}
