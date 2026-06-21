import AppKit
import CoreGraphics
import Foundation
import ImageIO

struct CropRequest {
  let sourcePath: String
  let outputPath: String
  let searchRect: CGRect
  let padding: Int
}

struct LoadedImage {
  let image: CGImage
  let data: Data
  let bytesPerRow: Int
  let width: Int
  let height: Int
}

let fileManager = FileManager.default
let root = fileManager.currentDirectoryPath

func absolute(_ path: String) -> String {
  URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: root)).standardized.path
}

func loadImage(_ relativePath: String) throws -> LoadedImage {
  let path = absolute(relativePath)
  guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        let provider = image.dataProvider,
        let cfData = provider.data else {
    throw NSError(domain: "split", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load \(path)"])
  }

  return LoadedImage(
    image: image,
    data: cfData as Data,
    bytesPerRow: image.bytesPerRow,
    width: image.width,
    height: image.height
  )
}

func isForeground(_ image: LoadedImage, x: Int, y: Int) -> Bool {
  let offset = y * image.bytesPerRow + x * 4
  let r = Int(image.data[offset])
  let g = Int(image.data[offset + 1])
  let b = Int(image.data[offset + 2])
  let maxValue = max(r, g, b)
  let minValue = min(r, g, b)
  return maxValue < 230 || (maxValue - minValue) > 8
}

func detectBoundingBox(in image: LoadedImage, searchRect: CGRect, padding: Int) -> CGRect {
  let minX = max(0, Int(searchRect.minX))
  let minY = max(0, Int(searchRect.minY))
  let maxX = min(image.width - 1, Int(searchRect.maxX))
  let maxY = min(image.height - 1, Int(searchRect.maxY))

  var found = false
  var left = maxX
  var right = minX
  var top = maxY
  var bottom = minY

  for y in minY...maxY {
    for x in minX...maxX {
      if isForeground(image, x: x, y: y) {
        found = true
        left = min(left, x)
        right = max(right, x)
        top = min(top, y)
        bottom = max(bottom, y)
      }
    }
  }

  if !found {
    return searchRect
  }

  let paddedLeft = max(0, left - padding)
  let paddedTop = max(0, top - padding)
  let paddedRight = min(image.width - 1, right + padding)
  let paddedBottom = min(image.height - 1, bottom + padding)

  return CGRect(
    x: paddedLeft,
    y: paddedTop,
    width: paddedRight - paddedLeft + 1,
    height: paddedBottom - paddedTop + 1
  )
}

func writeCrop(from image: LoadedImage, rect: CGRect, to relativeOutputPath: String) throws {
  guard let cropped = image.image.cropping(to: rect) else {
    throw NSError(domain: "split", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to crop \(relativeOutputPath)"])
  }

  let rep = NSBitmapImageRep(cgImage: cropped)
  guard let pngData = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "split", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode \(relativeOutputPath)"])
  }

  let outputPath = absolute(relativeOutputPath)
  let outputURL = URL(fileURLWithPath: outputPath)
  try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
  try pngData.write(to: outputURL)
}

let heroSearchX = [0, 175, 360, 545, 730, 915, 1100]
let heroSearchY = [0, 360, 720]
let minionSearchX = [40, 225, 410, 595, 780, 965, 1150]
let minionSearchY = [20, 290, 560, 830]

let heroSearchWidth = 170
let heroSearchHeight = 250
let minionSearchWidth = 150
let minionSearchHeight = 180

let heroNames = ["bow", "sword", "fist"]
let minionNames = ["blue_melee", "red_melee", "blue_ranged", "red_ranged"]

var requests: [CropRequest] = []

for (row, name) in heroNames.enumerated() {
  let y = heroSearchY[row]
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_idle_1.png", searchRect: CGRect(x: heroSearchX[0], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_idle_2.png", searchRect: CGRect(x: heroSearchX[1], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_run_1.png", searchRect: CGRect(x: heroSearchX[2], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_run_2.png", searchRect: CGRect(x: heroSearchX[3], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_run_3.png", searchRect: CGRect(x: heroSearchX[4], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_attack_1.png", searchRect: CGRect(x: heroSearchX[3], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_attack_2.png", searchRect: CGRect(x: heroSearchX[4], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_attack_3.png", searchRect: CGRect(x: heroSearchX[5], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
  requests.append(CropRequest(sourcePath: "assets/raw/hero_sheet.png", outputPath: "assets/raw/split/heroes/\(name)_attack_4.png", searchRect: CGRect(x: heroSearchX[6], y: y, width: heroSearchWidth, height: heroSearchHeight), padding: 8))
}

for (row, name) in minionNames.enumerated() {
  let y = minionSearchY[row]
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_idle_1.png", searchRect: CGRect(x: minionSearchX[0], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_idle_2.png", searchRect: CGRect(x: minionSearchX[1], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_idle_3.png", searchRect: CGRect(x: minionSearchX[2], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_run_1.png", searchRect: CGRect(x: minionSearchX[3], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_run_2.png", searchRect: CGRect(x: minionSearchX[4], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_run_3.png", searchRect: CGRect(x: minionSearchX[5], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_run_4.png", searchRect: CGRect(x: minionSearchX[6], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  if name.contains("melee") {
    requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_attack_1.png", searchRect: CGRect(x: minionSearchX[4], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
    requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_attack_2.png", searchRect: CGRect(x: minionSearchX[5], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
    requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_attack_3.png", searchRect: CGRect(x: minionSearchX[6], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  } else {
    requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_attack_1.png", searchRect: CGRect(x: minionSearchX[3], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
    requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_attack_2.png", searchRect: CGRect(x: minionSearchX[4], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
    requests.append(CropRequest(sourcePath: "assets/raw/minion_sheet.png", outputPath: "assets/raw/split/minions/\(name)_attack_3.png", searchRect: CGRect(x: minionSearchX[5], y: y, width: minionSearchWidth, height: minionSearchHeight), padding: 6))
  }
}

let heroImage = try loadImage("assets/raw/hero_sheet.png")
let minionImage = try loadImage("assets/raw/minion_sheet.png")
let imageMap = [
  "assets/raw/hero_sheet.png": heroImage,
  "assets/raw/minion_sheet.png": minionImage,
]

try? fileManager.removeItem(atPath: absolute("assets/raw/split"))
for request in requests {
  let image = imageMap[request.sourcePath]!
  let detectedRect = detectBoundingBox(in: image, searchRect: request.searchRect, padding: request.padding)
  try writeCrop(from: image, rect: detectedRect, to: request.outputPath)
}

print("Generated \(requests.count) cropped frames.")
