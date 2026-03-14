#!/usr/bin/env swift

import AppKit
import Foundation

// Create iconset directory
let iconsetPath = "/tmp/Kona.iconset"
let fileManager = FileManager.default

try? fileManager.removeItem(atPath: iconsetPath)
try! fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Icon sizes needed for macOS app icons
let sizes: [(name: String, size: Int, scale: Int)] = [
    ("icon_16x16", 16, 1),
    ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1),
    ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1),
    ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1),
    ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1),
    ("icon_512x512@2x", 512, 2)
]

// macOS squircle path (continuous corner radius like app icons)
func squirclePath(in rect: NSRect, cornerRadius: CGFloat) -> NSBezierPath {
    // Use a rounded rect with ~22.37% corner radius ratio (Apple's standard)
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    return path
}

for (name, size, scale) in sizes {
    let pixelSize = size * scale
    let imageSize = NSSize(width: pixelSize, height: pixelSize)
    
    let image = NSImage(size: imageSize)
    image.lockFocus()
    
    // Draw background squircle (fills entire icon area)
    let bgRect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    // Apple's standard corner radius is ~22.37% of icon size
    let cornerRadius = CGFloat(pixelSize) * 0.2237
    let bgPath = squirclePath(in: bgRect, cornerRadius: cornerRadius)
    
    // Gradient background (warm brown tones like coffee)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.45, green: 0.25, blue: 0.15, alpha: 1.0),
        NSColor(red: 0.35, green: 0.18, blue: 0.10, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: -90)
    
    // Draw SF Symbol
    if let symbolImage = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixelSize) * 0.5, weight: .medium)
        let configuredSymbol = symbolImage.withSymbolConfiguration(config)!
        
        let symbolSize = configuredSymbol.size
        let x = (CGFloat(pixelSize) - symbolSize.width) / 2
        let y = (CGFloat(pixelSize) - symbolSize.height) / 2
        
        // Draw symbol in white/cream color
        let tintedSymbol = NSImage(size: symbolSize)
        tintedSymbol.lockFocus()
        NSColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0).set()
        configuredSymbol.draw(in: NSRect(origin: .zero, size: symbolSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        NSRect(origin: .zero, size: symbolSize).fill(using: .sourceAtop)
        tintedSymbol.unlockFocus()
        
        tintedSymbol.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    
    image.unlockFocus()
    
    // Save as PNG
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let filePath = "\(iconsetPath)/\(name).png"
        try! pngData.write(to: URL(fileURLWithPath: filePath))
        print("Created \(name).png")
    }
}

print("\nIconset created at: \(iconsetPath)")
print("Run: iconutil -c icns \(iconsetPath)")
