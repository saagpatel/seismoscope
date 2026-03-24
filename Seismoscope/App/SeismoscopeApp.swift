import CoreMotion
import SwiftData
import SwiftUI

/// Thin Identifiable wrapper so UUID can be used with sheet(item:).
private struct SelectedEvent: Identifiable {
    let id: UUID
}

@main
struct SeismoscopeApp: App {
    @State private var appState = AppState()
    @State private var ribbonState = RibbonState()
    @State private var coordinator: EventCoordinator?
    @State private var syntheticSource: SyntheticDataSource?
    @State private var selectedEvent: SelectedEvent?
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: SeismicEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    private var isUsingLivePipeline: Bool { coordinator != nil }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RibbonContainerView(ribbonState: ribbonState) { eventId in
                    selectedEvent = SelectedEvent(id: eventId)
                }
                .ignoresSafeArea()

                StatusBarView(ribbonState: ribbonState) {
                    showSettings = true
                }

                #if DEBUG
                if !isUsingLivePipeline {
                    debugOverlay
                }
                #endif
            }
            .onAppear { startPipeline() }
            .onDisappear { stopPipeline() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    stopPipeline()
                case .active:
                    startPipeline()
                default:
                    break
                }
            }
            // Live-propagate settings changes to the running pipeline
            .onChange(of: appState.staLtaThreshold) { _, threshold in
                coordinator?.pipeline.updateThreshold(threshold)
            }
            .onChange(of: appState.region) { _, region in
                coordinator?.updateRegion(region)
            }
            .onChange(of: appState.lowPowerMode) { _, enabled in
                coordinator?.pipeline.setLowPowerMode(enabled)
            }
            .sheet(item: $selectedEvent) { selection in
                EventDetailView(eventId: selection.id)
                    .modelContainer(modelContainer)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appState: appState)
            }
        }
        .modelContainer(modelContainer)
    }

    private func startPipeline() {
        guard coordinator == nil, syntheticSource == nil else { return }

        if CMMotionManager().isAccelerometerAvailable {
            let pipeline = AccelerometerPipeline()
            // Apply current settings before starting
            pipeline.updateThreshold(appState.staLtaThreshold)
            pipeline.setLowPowerMode(appState.lowPowerMode)

            let coord = EventCoordinator(
                pipeline: pipeline,
                ribbonState: ribbonState,
                modelContext: modelContainer.mainContext,
                region: appState.region
            )
            pipeline.start()
            coord.start()
            coordinator = coord
        } else {
            // Simulator fallback — use synthetic data
            let source = SyntheticDataSource(ribbonState: ribbonState)
            source.start()
            syntheticSource = source
        }
    }

    private func stopPipeline() {
        coordinator?.stop()
        coordinator = nil
        syntheticSource?.stop()
        syntheticSource = nil
    }

    #if DEBUG
    @ViewBuilder
    private var debugOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                ForEach(SyntheticDataSource.Mode.allCases, id: \.rawValue) { mode in
                    Button(mode.rawValue.capitalized) {
                        syntheticSource?.configuration.mode = mode
                        if mode == .impulse {
                            syntheticSource?.triggerImpulse()
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .padding(.bottom, 40)
        }
    }
    #endif
}
