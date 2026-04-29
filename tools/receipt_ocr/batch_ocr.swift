#!/usr/bin/env swift
import AppKit
import Foundation
import Vision

struct Arguments {
    var input: String = ""
    var output: String = ""
    var outputDir: String?
    var limit: Int?
}

struct OCRLine: Encodable {
    let id: String
    let imagePathHash: String
    let width: Int
    let height: Int
    let ocrText: String
    let minConfidence: Float
    let meanConfidence: Float
    let lineCount: Int
    let durationMs: Int
    let error: String?
}

func parseArguments() -> Arguments {
    var args = Arguments()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--input":
            args.input = iterator.next() ?? ""
        case "--output":
            args.output = iterator.next() ?? ""
        case "--output-dir":
            args.outputDir = iterator.next() ?? ""
        case "--limit":
            args.limit = Int(iterator.next() ?? "")
        default:
            break
        }
    }
    return args
}

func stableHash(_ value: String) -> String {
    String(value.unicodeScalars.reduce(UInt64(1469598103934665603)) { hash, scalar in
        (hash ^ UInt64(scalar.value)) &* 1099511628211
    }, radix: 16)
}

func imageFiles(in directory: URL, limit: Int?) throws -> [URL] {
    let extensions = Set(["jpg", "jpeg", "png", "heic", "tif", "tiff"])
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    let images = urls
        .filter { extensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    if let limit {
        return Array(images.prefix(limit))
    }
    return images
}

func recognize(url: URL) -> OCRLine {
    let start = Date()
    let id = url.deletingPathExtension().lastPathComponent

    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return OCRLine(
            id: id,
            imagePathHash: stableHash(url.path),
            width: 0,
            height: 0,
            ocrText: "",
            minConfidence: 0,
            meanConfidence: 0,
            lineCount: 0,
            durationMs: Int(Date().timeIntervalSince(start) * 1000),
            error: "image_load_failed"
        )
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["zh-Hans", "en-US"]

    do {
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
        let text = candidates.map(\.string).joined(separator: "\n")
        let confidences = candidates.map(\.confidence)
        return OCRLine(
            id: id,
            imagePathHash: stableHash(url.path),
            width: cgImage.width,
            height: cgImage.height,
            ocrText: text,
            minConfidence: confidences.min() ?? 0,
            meanConfidence: confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count),
            lineCount: candidates.count,
            durationMs: Int(Date().timeIntervalSince(start) * 1000),
            error: nil
        )
    } catch {
        return OCRLine(
            id: id,
            imagePathHash: stableHash(url.path),
            width: cgImage.width,
            height: cgImage.height,
            ocrText: "",
            minConfidence: 0,
            meanConfidence: 0,
            lineCount: 0,
            durationMs: Int(Date().timeIntervalSince(start) * 1000),
            error: error.localizedDescription
        )
    }
}

let args = parseArguments()
guard !args.input.isEmpty, !args.output.isEmpty else {
    FileHandle.standardError.write(Data("Usage: swift batch_ocr.swift --input <dir> --output <jsonl> [--output-dir <dir>] [--limit N]\n".utf8))
    exit(2)
}

let inputURL = URL(fileURLWithPath: args.input)
let outputURL = URL(fileURLWithPath: args.output)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let perFileOutputURL = args.outputDir.map { URL(fileURLWithPath: $0) }
if let perFileOutputURL {
    try FileManager.default.createDirectory(
        at: perFileOutputURL,
        withIntermediateDirectories: true
    )
}

let lines = try imageFiles(in: inputURL, limit: args.limit).map { url in
    let record = recognize(url: url)
    let data = try encoder.encode(record)
    if let perFileOutputURL {
        let baseURL = perFileOutputURL.appendingPathComponent(record.id)
        try record.ocrText.write(
            to: baseURL.appendingPathExtension("txt"),
            atomically: true,
            encoding: .utf8
        )
        try data.write(to: baseURL.appendingPathExtension("json"), options: [.atomic])
    }
    return String(decoding: data, as: UTF8.self)
}
try lines.joined(separator: "\n").appending("\n").write(to: outputURL, atomically: true, encoding: .utf8)
if let perFileOutputURL {
    print("Wrote \(lines.count) OCR records to \(outputURL.path) and per-image files to \(perFileOutputURL.path)")
} else {
    print("Wrote \(lines.count) OCR records to \(outputURL.path)")
}
