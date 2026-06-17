#!/usr/bin/env swift
//
// Generates the Eyeline app icon: a centered text-lines glyph (echoing the menu-bar
// `text.aligncenter` symbol) on a gradient "squircle", exported at every macOS app-icon size.
//
// macOS does NOT auto-mask app icons (unlike iOS), so we draw the rounded rectangle, gradient,
// and a subtle drop shadow ourselves. Run:
//
//   swift scripts/generate_app_icon.swift Eyeline/Assets.xcassets/AppIcon.appiconset
//
// Committed so the icon is reproducible — re-run after tweaking colours/glyph below.

import AppKit
import Foundation

// MARK: - Tunables (the whole look lives here)

let topColor    = NSColor(srgbRed: 0.36, green: 0.47, blue: 0.98, alpha: 1)  // light indigo
let bottomColor = NSColor(srgbRed: 0.17, green: 0.25, blue: 0.78, alpha: 1)  // deep indigo
let glyphColor  = NSColor.white
let marginFrac  = 0.085   // transparent breathing room around the squircle
let cornerFrac  = 0.2237  // Apple's Big Sur squircle corner-radius ratio
// Relative bar widths, top→bottom — centered, alternating long/short to read as "centered text".
let barWidths: [CGFloat] = [0.92, 0.62, 0.82, 0.50]

// MARK: - Render

func makeIconPNG(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let cg = nsCtx.cgContext

    cg.clear(CGRect(x: 0, y: 0, width: s, height: s))

    let margin = s * marginFrac
    let rect = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let radius = rect.width * cornerFrac
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow for depth (Big Sur style). Cast by filling the shape opaque first.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                 blur: s * 0.03,
                 color: NSColor.black.withAlphaComponent(0.28).cgColor)
    cg.addPath(squircle)
    cg.setFillColor(NSColor.white.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Vertical gradient, clipped to the squircle.
    cg.saveGState()
    cg.addPath(squircle)
    cg.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                          locations: [0, 1])!
    cg.drawLinearGradient(grad,
                          start: CGPoint(x: rect.midX, y: rect.maxY),
                          end: CGPoint(x: rect.midX, y: rect.minY),
                          options: [])
    cg.restoreGState()

    // Centered text-line bars.
    let glyphWidth = rect.width * 0.56
    let barHeight = rect.height * 0.075
    let gap = barHeight * 0.95
    let blockHeight = CGFloat(barWidths.count) * barHeight + CGFloat(barWidths.count - 1) * gap
    var y = rect.midY + blockHeight / 2 - barHeight
    cg.setFillColor(glyphColor.cgColor)
    for w in barWidths {
        let bw = glyphWidth * w
        let bar = CGRect(x: rect.midX - bw / 2, y: y, width: bw, height: barHeight)
        cg.addPath(CGPath(roundedRect: bar, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        cg.fillPath()
        y -= (barHeight + gap)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Write

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for px in [16, 32, 64, 128, 256, 512, 1024] {
    let data = makeIconPNG(pixels: px)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("icon_\(px).png")
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(data.count) bytes)")
}
print("done")
