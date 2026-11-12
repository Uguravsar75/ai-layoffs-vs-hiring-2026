// Renders each page of powerbi/dashboard.pdf to a PNG (2x scale) using macOS PDFKit.
// Usage (from the project root): swift powerbi/pdf_to_png.swift powerbi/dashboard.pdf powerbi/screenshots

import PDFKit
import AppKit
let args = CommandLine.arguments
guard args.count >= 3, let doc = PDFDocument(url: URL(fileURLWithPath: args[1])) else { print("usage: pdf2png in.pdf outdir"); exit(1) }
let names = ["01_overview", "02_ai_narrative", "03_hiring_side", "04_data_reliability"]
let scale: CGFloat = 2.0
for i in 0..<doc.pageCount {
    guard let page = doc.page(at: i) else { continue }
    let box = page.bounds(for: .mediaBox)
    let size = NSSize(width: box.width * scale, height: box.height * scale)
    let img = NSImage(size: size)
    img.lockFocus()
    NSColor.white.set(); NSRect(origin: .zero, size: size).fill()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    let name = i < names.count ? names[i] : String(format: "page_%02d", i + 1)
    try! png.write(to: URL(fileURLWithPath: args[2]).appendingPathComponent(name + ".png"))
    print("wrote \(name).png \(Int(size.width))x\(Int(size.height))")
}
