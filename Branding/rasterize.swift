#!/usr/bin/env swift
// Rasterise an SVG at an exact pixel size via AppKit.
// Usage: swift rasterize.swift <input.svg> <size> <output.png>
import AppKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: rasterize.swift <in.svg> <size> <out.png>\n".utf8))
    exit(64)
}
let input  = URL(fileURLWithPath: CommandLine.arguments[1])
let size   = Int(CommandLine.arguments[2]) ?? 0
let output = URL(fileURLWithPath: CommandLine.arguments[3])
guard size > 0 else { exit(64) }

guard let source = NSImage(contentsOf: input) else {
    FileHandle.standardError.write(Data("couldn't read \(input.path)\n".utf8))
    exit(1)
}

let px = CGFloat(size)
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 32
)!
rep.size = NSSize(width: px, height: px)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
source.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
            from: .zero, operation: .copy, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}
try data.write(to: output)
print("wrote \(output.lastPathComponent) (\(size)x\(size))")
