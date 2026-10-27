#!/usr/bin/env swift

// Dibuja el icono de Replacer en código — el mismo glifo que `AppGlyph` en
// ContentView.swift (degradado azul→verde azulado y el símbolo
// `arrow.left.arrow.right` en blanco) — y lo exporta a:
//   - Assets/AppIcon/Replacer-master.png (1024 px, referencia)
//   - Assets/AppIcon/Replacer.iconset + Replacer.icns (build SwiftPM/DMG)
//   - Replacer/Replacer/Assets.xcassets/AppIcon.appiconset (target de Xcode)
//
// Ejecutar desde la raíz del repo: `swift scripts/generate-icon.swift`.

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = rootURL
    .appendingPathComponent("Assets")
    .appendingPathComponent("AppIcon")
let iconsetURL = assetsURL.appendingPathComponent("Replacer.iconset")
let masterURL = assetsURL.appendingPathComponent("Replacer-master.png")
let appIconSetURL = rootURL
    .appendingPathComponent("Replacer/Replacer/Assets.xcassets/AppIcon.appiconset")

// Mismos colores que ReplacerTheme.blue / ReplacerTheme.teal en modo claro.
let gradientStart = NSColor(calibratedRed: 0.13, green: 0.36, blue: 0.92, alpha: 1)
let gradientEnd = NSColor(calibratedRed: 0.00, green: 0.66, blue: 0.58, alpha: 1)

let iconsetFiles: [(String, Int)] = [
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

// Nombres que usa el Contents.json del asset catalog de Xcode.
let appIconSetFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_1024x1024.png", 1024)
]

// Dibuja directamente sobre un NSBitmapImageRep de tamaño en píxeles exacto.
// `NSImage(size:) + lockFocus()` respeta el factor Retina de la pantalla que
// ejecuta el script (normalmente 2x), duplicando el tamaño real de cada PNG
// respecto al que indica su nombre de archivo — por eso no se usa aquí.
// El fondo queda transparente fuera del rectángulo redondeado, como el resto
// de iconos de macOS; la rejilla de Apple deja ~10 % de margen por lado.
func renderIcon(pixels: Int) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
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

    let side = CGFloat(pixels)
    let inset = side * 100 / 1024
    let tile = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let radius = tile.width * 0.225
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    // Sombra suave bajo la placa, como en los iconos del sistema.
    if pixels >= 64 {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = side * 0.02
        shadow.shadowOffset = NSSize(width: 0, height: -side * 0.01)
        shadow.set()
        gradientStart.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // Degradado de arriba-izquierda a abajo-derecha (ángulo -45° en AppKit,
    // cuyo eje Y crece hacia arriba).
    NSGradient(starting: gradientStart, ending: gradientEnd)?.draw(in: path, angle: -45)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: tile.width * 0.44, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    guard
        let symbol = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
    else {
        throw NSError(domain: "ReplacerIcon", code: 5, userInfo: [NSLocalizedDescriptionKey: "No se encontró el símbolo arrow.left.arrow.right"])
    }

    let symbolSize = symbol.size
    let symbolRect = NSRect(
        x: tile.midX - symbolSize.width / 2,
        y: tile.midY - symbolSize.height / 2,
        width: symbolSize.width,
        height: symbolSize.height
    )
    symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ReplacerIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear PNG"])
    }

    try pngData.write(to: url, options: .atomic)
}

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

var rendered: [Int: NSBitmapImageRep] = [:]
func icon(_ pixels: Int) throws -> NSBitmapImageRep {
    if let rep = rendered[pixels] { return rep }
    let rep = try renderIcon(pixels: pixels)
    rendered[pixels] = rep
    return rep
}

try writePNG(icon(1024), to: masterURL)

for (filename, pixels) in iconsetFiles {
    try writePNG(icon(pixels), to: iconsetURL.appendingPathComponent(filename))
}

if FileManager.default.fileExists(atPath: appIconSetURL.path) {
    for (filename, pixels) in appIconSetFiles {
        try writePNG(icon(pixels), to: appIconSetURL.appendingPathComponent(filename))
    }
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

print("Icono generado en \(assetsURL.path) y \(appIconSetURL.path)")
