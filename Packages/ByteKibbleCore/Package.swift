// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "ByteKibbleCore", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ByteKibbleCore", targets: ["ByteKibbleCore"])],
    targets: [.target(name: "ByteKibbleCore"), .testTarget(name: "ByteKibbleCoreTests", dependencies: ["ByteKibbleCore"])])
