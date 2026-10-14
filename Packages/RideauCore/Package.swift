// swift-tools-version: 6.0
import Foundation
import PackageDescription

let kit: Package.Dependency = ProcessInfo.processInfo.environment["VIALETKIT_PATH"]
    .map { .package(path: $0) } ?? .package(url: "https://github.com/avialet/vialetkit.git", .upToNextMinor(from: "0.2.6"))

let package = Package(
    name: "RideauCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RideauCore", targets: ["RideauCore"]),
    ],
    dependencies: [
        kit,
    ],
    targets: [
        // Logique pure : plans de masquage et de restitution, ordre des fenetres, etat sauvegarde,
        // machine du rideau, cadrage du fond d'ecran. Ni AppKit, ni base de donnees.
        .target(
            name: "RideauCore",
            dependencies: [
                .product(name: "VialetKit", package: "vialetkit"),
            ]
        ),
        // Harnais de tests : XCTest et Swift Testing ne sont pas livres avec
        // les Command Line Tools (voir docs/tests.md).
        .executableTarget(
            name: "rideaucore-check",
            dependencies: ["RideauCore"]
        ),
    ]
)
