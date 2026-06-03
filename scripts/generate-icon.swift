#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourceURL = rootURL
    .appendingPathComponent("Sources")
    .appendingPathComponent("FileReplaceApp")
    .appendingPathComponent("Resources")
let assetsURL = rootURL
    .appendingPathComponent("Assets")
    .appendingPathComponent("AppIcon")
let iconsetURL = assetsURL.appendingPathComponent("Replacer.iconset")

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

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let cornerRadius = size * 0.225
    let backgroundRect = rect.insetBy(dx: size * 0.055, dy: size * 0.055)
    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.27, blue: 0.82, alpha: 1),
        NSColor(calibratedRed: 0.00, green: 0.72, blue: 0.64, alpha: 1)
    ])
    gradient?.draw(in: backgroundPath, angle: 135)

    NSColor.black.withAlphaComponent(0.18).setStroke()
    backgroundPath.lineWidth = max(1, size * 0.015)
    backgroundPath.stroke()

    let documentRect = NSRect(
        x: size * 0.25,
        y: size * 0.22,
        width: size * 0.38,
        height: size * 0.56
    )
    let documentPath = NSBezierPath(roundedRect: documentRect, xRadius: size * 0.045, yRadius: size * 0.045)
    NSColor.white.withAlphaComponent(0.94).setFill()
    documentPath.fill()

    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: documentRect.maxX - size * 0.13, y: documentRect.maxY))
    foldPath.line(to: NSPoint(x: documentRect.maxX, y: documentRect.maxY - size * 0.13))
    foldPath.line(to: NSPoint(x: documentRect.maxX - size * 0.13, y: documentRect.maxY - size * 0.13))
    foldPath.close()
    NSColor(calibratedRed: 0.78, green: 0.88, blue: 1.0, alpha: 1).setFill()
    foldPath.fill()

    NSColor(calibratedRed: 0.08, green: 0.27, blue: 0.82, alpha: 0.75).setStroke()
    for index in 0..<3 {
        let y = documentRect.maxY - size * (0.22 + CGFloat(index) * 0.12)
        let line = NSBezierPath()
        line.move(to: NSPoint(x: documentRect.minX + size * 0.09, y: y))
        line.line(to: NSPoint(x: documentRect.maxX - size * 0.09, y: y))
        line.lineWidth = max(1.5, size * 0.026)
        line.lineCapStyle = .round
        line.stroke()
    }

    let lensRect = NSRect(
        x: size * 0.54,
        y: size * 0.22,
        width: size * 0.21,
        height: size * 0.21
    )
    let lens = NSBezierPath(ovalIn: lensRect)
    NSColor.white.setStroke()
    lens.lineWidth = max(2.5, size * 0.045)
    lens.stroke()

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: lensRect.maxX - size * 0.015, y: lensRect.minY + size * 0.015))
    handle.line(to: NSPoint(x: size * 0.83, y: size * 0.13))
    handle.lineCapStyle = .round
    handle.lineWidth = max(2.5, size * 0.045)
    handle.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: size * 0.28, y: size * 0.18))
    arrow.line(to: NSPoint(x: size * 0.47, y: size * 0.18))
    arrow.line(to: NSPoint(x: size * 0.42, y: size * 0.13))
    arrow.move(to: NSPoint(x: size * 0.47, y: size * 0.18))
    arrow.line(to: NSPoint(x: size * 0.42, y: size * 0.23))
    NSColor.white.withAlphaComponent(0.9).setStroke()
    arrow.lineWidth = max(2, size * 0.03)
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()

    return image
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
    try writePNG(drawIcon(size: size), to: iconsetURL.appendingPathComponent(filename))
}

let previewURL = resourceURL.appendingPathComponent("AppIconPreview.png")
if !FileManager.default.fileExists(atPath: previewURL.path) {
    try FileManager.default.createDirectory(at: resourceURL, withIntermediateDirectories: true)
    try writePNG(drawIcon(size: 256), to: previewURL)
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

print("Icono generado en \(assetsURL.path)")
