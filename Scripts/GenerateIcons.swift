#!/usr/bin/env swift
import CoreGraphics
import ImageIO
import Foundation

func createIcon(size: CGFloat) -> CGImage? {
    let s = Int(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: s, height: s,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Flip: origin top-left, y down
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    // Clip to rounded rect
    let r = size * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.addPath(CGPath(roundedRect: bgRect, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.clip()

    // Background gradient: steel-blue top → dark navy bottom
    let bgGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.18, green: 0.42, blue: 0.78, alpha: 1.0),
            CGColor(red: 0.05, green: 0.13, blue: 0.35, alpha: 1.0)
        ] as CFArray,
        locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGrad,
                           start: CGPoint(x: size/2, y: 0),
                           end:   CGPoint(x: size/2, y: size),
                           options: [])

    // Top radial highlight
    let hlGrad = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red:1,green:1,blue:1,alpha:0.18),
                 CGColor(red:1,green:1,blue:1,alpha:0.0)] as CFArray,
        locations: [0.0, 1.0])!
    ctx.drawRadialGradient(hlGrad,
                           startCenter: CGPoint(x: size*0.5, y: size*0.18), startRadius: 0,
                           endCenter:   CGPoint(x: size*0.5, y: size*0.18), endRadius: size*0.55,
                           options: [])

    // Microphone capsule (white)
    let mW = size * 0.24, mH = size * 0.36
    let mX = (size - mW) / 2, mY = size * 0.12
    ctx.setFillColor(CGColor(red:1,green:1,blue:1,alpha:1))
    ctx.addPath(CGPath(roundedRect: CGRect(x:mX, y:mY, width:mW, height:mH),
                       cornerWidth: mW/2, cornerHeight: mW/2, transform: nil))
    ctx.fillPath()

    // Grill lines on mic
    ctx.setStrokeColor(CGColor(red:0.18, green:0.42, blue:0.78, alpha:0.3))
    ctx.setLineWidth(size * 0.018)
    for i in 1...4 {
        let y = mY + mH * CGFloat(i) / 5.0
        ctx.move(to: CGPoint(x: mX + size*0.04, y: y))
        ctx.addLine(to: CGPoint(x: mX + mW - size*0.04, y: y))
    }
    ctx.strokePath()

    // Stand arc
    ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:1))
    ctx.setLineWidth(size * 0.055)
    ctx.setLineCap(.round)
    let aCX = size/2, aCY = mY + mH + size*0.015, aR = mW * 0.92
    let arcPath = CGMutablePath()
    arcPath.addArc(center: CGPoint(x: aCX, y: aCY),
                   radius: aR, startAngle: .pi, endAngle: 0, clockwise: false)
    ctx.addPath(arcPath)
    ctx.strokePath()

    // Vertical stem
    let stemTop = aCY + aR, stemBot = stemTop + size * 0.075
    ctx.move(to: CGPoint(x: size/2, y: stemTop))
    ctx.addLine(to: CGPoint(x: size/2, y: stemBot))
    ctx.strokePath()

    // Horizontal base
    let bW = mW * 1.35
    ctx.move(to: CGPoint(x: size/2 - bW/2, y: stemBot))
    ctx.addLine(to: CGPoint(x: size/2 + bW/2, y: stemBot))
    ctx.strokePath()

    // Note lines at bottom
    ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:0.55))
    ctx.setLineWidth(size * 0.038)
    let nlW = size * 0.36, nlX = (size - nlW) / 2
    ctx.move(to: CGPoint(x: nlX,       y: size * 0.79))
    ctx.addLine(to: CGPoint(x: nlX + nlW, y: size * 0.79))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: nlX,           y: size * 0.88))
    ctx.addLine(to: CGPoint(x: nlX + nlW * 0.62, y: size * 0.88))
    ctx.strokePath()

    return ctx.makeImage()
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("❌ no dest: \(path)"); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    print(CGImageDestinationFinalize(dest) ? "✅ \(path)" : "❌ \(path)")
}

let base = "/Users/marcjurriens/Applications/SilverNotes/SilverNotes/.claude/worktrees/recursing-black"

// iOS icon (1024×1024)
let iosDir = "\(base)/SilverNotes/Assets.xcassets/AppIcon.appiconset"
if let img = createIcon(size: 1024) { savePNG(img, to: "\(iosDir)/AppIcon.png") }

// watchOS assets dir
let watchAssetsDir = "\(base)/SilverNotesWatch/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: watchAssetsDir, withIntermediateDirectories: true)

for sz in [1024, 216, 196, 172, 100, 88, 87, 80, 58, 55, 48, 44, 40, 29] {
    if let img = createIcon(size: CGFloat(sz)) {
        savePNG(img, to: "\(watchAssetsDir)/AppIcon-\(sz).png")
    }
}

print("Done!")
