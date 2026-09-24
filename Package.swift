// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Bustelo", platforms: [.macOS(.v13)],
    products: [.executable(name: "Bustelo", targets: ["Bustelo"])],
    targets: [.executableTarget(name: "Bustelo")]
)
