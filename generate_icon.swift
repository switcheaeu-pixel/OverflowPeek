#!/usr/bin/env swift

import Cocoa
import CoreGraphics

// MARK: - App Icon Generator for Overflow Peek
// Generates all .iconset sizes for AppIcon.icns. Run from project root.

func drawAppIcon(size: CGSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(origin: .zero, size: size)
    let w = size.width

    // Squircle base
    let cornerRadius = w * 0.225
    let squircle = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    squircle.addClip()

    // Background gradient: deep indigo -> violet
    let bgColors = [
        NSColor(calibratedRed: 0.27, green: 0.20, blue: 0.55, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.78, alpha: 1.0).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: bgColors as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: w),
                           end: CGPoint(x: w, y: 0),
                           options: [])

    // Subtle inner highlight stroke
    NSColor.white.withAlphaComponent(0.10).setStroke()
    let inner = NSBezierPath(roundedRect: rect.insetBy(dx: w * 0.018, dy: w * 0.018),
                             xRadius: cornerRadius * 0.92,
                             yRadius: cornerRadius * 0.92)
    inner.lineWidth = w * 0.006
    inner.stroke()

    // Layered "peek" cards
    let cardRadius = w * 0.10
    let center = CGPoint(x: w * 0.50, y: w * 0.48)
    let baseSize = w * 0.50

    struct Card {
        let offset: CGPoint
        let scale: CGFloat
        let alpha: CGFloat
    }
    let cards: [Card] = [
        Card(offset: CGPoint(x:  0.085, y: -0.085), scale: 0.78, alpha: 0.18),
        Card(offset: CGPoint(x:  0.040, y: -0.040), scale: 0.88, alpha: 0.45),
        Card(offset: CGPoint(x:  0.000, y:  0.000), scale: 1.00, alpha: 1.0)
    ]

    for card in cards {
        ctx.saveGState()
        let cs = baseSize * card.scale
        let cx = center.x - cs / 2 + card.offset.x * w
        let cy = center.y - cs / 2 + card.offset.y * w
        let cardRect = CGRect(x: cx, y: cy, width: cs, height: cs)
        let path = NSBezierPath(roundedRect: cardRect,
                                xRadius: cardRadius * card.scale,
                                yRadius: cardRadius * card.scale)

        if card.alpha >= 1.0 {
            ctx.setShadow(offset: CGSize(width: 0, height: -w * 0.012),
                          blur: w * 0.04,
                          color: NSColor.black.withAlphaComponent(0.35).cgColor)
        }
        NSColor.white.withAlphaComponent(card.alpha).setFill()
        path.fill()
        ctx.restoreGState()

        if card.alpha >= 1.0 {
            ctx.saveGState()
            let inset = cs * 0.20
            let innerRect = cardRect.insetBy(dx: inset, dy: inset)
            let dotSize = innerRect.width * 0.36
            let gap = innerRect.width - dotSize
            let dotColor = NSColor(calibratedRed: 0.27, green: 0.20, blue: 0.55, alpha: 1.0)
            let accent  = NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.55, alpha: 1.0)
            for row in 0..<2 {
                for col in 0..<2 {
                    let dx = innerRect.minX + CGFloat(col) * gap
                    let dy = innerRect.maxY - dotSize - CGFloat(row) * gap
                    let dotRect = CGRect(x: dx, y: dy, width: dotSize, height: dotSize)
                    let dotPath = NSBezierPath(roundedRect: dotRect,
                                               xRadius: dotSize * 0.28,
                                               yRadius: dotSize * 0.28)
                    if row == 0 && col == 1 {
                        accent.setFill()
                    } else {
                        dotColor.setFill()
                    }
                    dotPath.fill()
                }
            }
            ctx.restoreGState()
        }
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        print("FAIL: could not encode \(path)")
        return
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    } catch {
        print("FAIL write \(path): \(error)")
    }
}

let iconsetDir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (64,   "icon_64x64.png"),
    (128,  "icon_64x64@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
    (1024, "icon_1024x1024.png"),
    (1024, "icon_1024x1024@2x.png"),
]

for (px, name) in sizes {
    let img = drawAppIcon(size: CGSize(width: px, height: px))
    writePNG(img, to: "\(iconsetDir)/\(name)")
}

print("Done generating iconset")
