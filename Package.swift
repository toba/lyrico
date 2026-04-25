// swift-tools-version: 6.3

import PackageDescription

let strictSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableExperimentalFeature("StrictMemorySafety"),
  .treatAllWarnings(as: .error),
]

let package = Package(
  name: "Lyrico",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "LyricoKit", targets: ["LyricoKit"])
  ],
  dependencies: [
    .package(url: "https://github.com/toba/swiftiomatic-plugins", from: "0.32.2"),
  ],
  targets: [
    .target(
      name: "LyricoKit",
      path: "Sources/LyricoKit",
      swiftSettings: strictSettings,
      plugins: [
        .plugin(name: "SwiftiomaticBuildToolPlugin", package: "swiftiomatic-plugins"),
      ]
    ),
    .testTarget(
      name: "LyricoKitTests",
      dependencies: ["LyricoKit"],
      swiftSettings: strictSettings,
      plugins: [
        .plugin(name: "SwiftiomaticBuildToolPlugin", package: "swiftiomatic-plugins"),
      ]
    ),
  ]
)
