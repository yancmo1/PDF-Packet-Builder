// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDFPacketSender",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "PDFPacketSender",
            targets: ["PDFPacketSender"]),
    ],
    targets: [
        .target(
            name: "PDFPacketSender",
            path: "PDFPacketSender")
    ]
)
