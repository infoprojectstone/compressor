// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CompresorUnificado",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CompresorUnificado", targets: ["CompresorUnificado"]),
        .executable(name: "VerifyCompression", targets: ["VerifyCompression"])
    ],
    targets: [
        .executableTarget(name: "CompresorUnificado", path: "Sources/CompresorUnificado"),
        .executableTarget(name: "VerifyCompression", path: "Tools/VerifyCompression")
    ]
)
