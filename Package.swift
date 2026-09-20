// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ByteKibble",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"), .package(path: "Packages/ByteKibbleCore")],
    targets: [
        .executableTarget(
            name: "ByteKibble",
            dependencies: [.product(name: "Sparkle", package: "Sparkle"), .product(name: "ByteKibbleCore", package: "ByteKibbleCore")],
            path: "Sources/ByteKibble",
            resources: [
                .copy("Resources/QuotaBag.png"),
                .copy("Resources/WelcomeArtwork.png"),
                .copy("Resources/MULabsWordmark.png"),
                .copy("Resources/catfood.svg"),
                .copy("Resources/en.lproj"),
                .copy("Resources/zh-Hans.lproj"),
                .copy("Resources/zh-Hant.lproj"),
                .copy("Resources/ja.lproj"),
                .copy("Resources/ko.lproj")
            ]
        ),
        .testTarget(name: "ByteKibbleTests", dependencies: ["ByteKibble"])
    ]
)
