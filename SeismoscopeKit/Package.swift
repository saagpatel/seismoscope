// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeismoscopeKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SeismoscopeKit", targets: ["SeismoscopeKit"])
    ],
    targets: [
        .target(name: "SeismoscopeKit"),
        .testTarget(name: "SeismoscopeKitTests", dependencies: ["SeismoscopeKit"])
    ]
)
