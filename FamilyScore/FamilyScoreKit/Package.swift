// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FamilyScoreKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FamilyScoreKit", targets: ["FamilyScoreKit"])
    ],
    targets: [
        .target(
            name: "FamilyScoreKit",
            path: "Sources/FamilyScoreKit"
        )
    ]
)
