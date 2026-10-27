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

// Dibuja directamente sobre un NSBitmapImageRep de tamaño en píxeles exacto.
// `NSImage(size:) + lockFocus()` respeta el factor Retina de la pantalla que
// ejecuta el script (normalmente 2x), duplicando el tamaño real de cada PNG
// respecto al que indica su nombre de archivo — por eso no se usa aquí.
// `samplesPerPixel: 3, hasAlpha: false` fuerza además un PNG sin canal alfa,
// que es lo que exige Xcode para los iconos de App Store.
func resizedIcon(from source: NSImage, pixels: Int) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 3,
        hasAlpha: false,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "ReplacerIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el bitmap de \(pixels)px"])
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    let context = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = context
    context?.imageInterpolation = .high

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.white.setFill()
    rect.fill()
    source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ReplacerIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear PNG"])
    }

    try pngData.write(to: url, options: .atomic)
}

for (filename, size) in iconFiles {
    let rep = try resizedIcon(from: masterImage, pixels: Int(size))
    try writePNG(rep, to: iconsetURL.appendingPathComponent(filename))
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
