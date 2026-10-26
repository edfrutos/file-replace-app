#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = rootURL
    .appendingPathComponent("Assets")
    .appendingPathComponent("AppIcon")
let iconsetURL = assetsURL.appendingPathComponent("Replacer.iconset")
let masterURL = assetsURL.appendingPathComponent("Replacer-master.png")

guard let masterImage = NSImage(contentsOf: masterURL) else {
    throw NSError(
        domain: "ReplacerIcon",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "No se encontró el icono maestro en \(masterURL.path)"]
    )
}

guard masterImage.size.width == masterImage.size.height else {
    throw NSError(
        domain: "ReplacerIcon",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "El icono maestro debe ser cuadrado (actual: \(masterImage.size))"]
    )
}

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func resizedIcon(from source: NSImage, size: CGFloat) -> NSImage {
    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    defer { target.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )

    return target
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ReplacerIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear PNG"])
    }

    try pngData.write(to: url, options: .atomic)
}

for (filename, size) in iconFiles {
    try writePNG(resizedIcon(from: masterImage, size: size), to: iconsetURL.appendingPathComponent(filename))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c",
    "icns",
    iconsetURL.path,
    "-o",
    assetsURL.appendingPathComponent("Replacer.icns").path
]
try iconutil.run()
iconutil.waitUntilExit()

if iconutil.terminationStatus != 0 {
    throw NSError(domain: "ReplacerIcon", code: Int(iconutil.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil no pudo generar Replacer.icns"])
}

print("Icono generado a partir de \(masterURL.lastPathComponent) en \(assetsURL.path)")
