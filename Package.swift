// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Bignum",
    products: [
        .library(name: "Bignum", targets: ["Bignum"])
    ],
    targets: [
        .target(name: "Bignum", dependencies: ["CGMP"]),
        .systemLibrary(name: "CGMP", pkgConfig: "gmp", providers: [.brew(["gmp"], .apt(["libgmp-dev"]))])
    ]
)
