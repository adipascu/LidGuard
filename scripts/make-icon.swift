import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let radius = size * 0.2237
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.16, alpha: 1),
    NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.35, alpha: 1),
])!
gradient.draw(in: path, angle: 90)

let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .medium)
if let symbol = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let r = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let target = NSRect(
        x: (size - tinted.size.width) / 2,
        y: (size - tinted.size.height) / 2 + size * 0.06,
        width: tinted.size.width,
        height: tinted.size.height)
    tinted.draw(in: target)
}

let barConfig = NSImage.SymbolConfiguration(pointSize: size * 0.26, weight: .bold)
if let slash = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: nil)?
    .withSymbolConfiguration(barConfig) {
    let tinted = NSImage(size: slash.size)
    tinted.lockFocus()
    NSColor(calibratedRed: 0.45, green: 0.83, blue: 0.98, alpha: 1).set()
    let r = NSRect(origin: .zero, size: slash.size)
    slash.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let target = NSRect(
        x: (size - tinted.size.width) / 2,
        y: size * 0.17,
        width: tinted.size.width,
        height: tinted.size.height)
    tinted.draw(in: target)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { exit(1) }

try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
