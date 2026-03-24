import SwiftUI

@main
struct SeismoscopeApp: App {
    @State private var ribbonState = RibbonState()
    @State private var dataSource: SyntheticDataSource?

    var body: some Scene {
        WindowGroup {
            ZStack {
                RibbonContainerView(ribbonState: ribbonState)
                    .ignoresSafeArea()

                #if DEBUG
                debugOverlay
                #endif
            }
            .onAppear {
                let source = SyntheticDataSource(ribbonState: ribbonState)
                source.start()
                dataSource = source
            }
            .onDisappear {
                dataSource?.stop()
            }
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                ForEach(SyntheticDataSource.Mode.allCases, id: \.rawValue) { mode in
                    Button(mode.rawValue.capitalized) {
                        dataSource?.configuration.mode = mode
                        if mode == .impulse {
                            dataSource?.triggerImpulse()
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
