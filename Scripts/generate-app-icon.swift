#!/usr/bin/env swift

// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IconPipelineError: Error, CustomStringConvertible {
    case invalidArguments
    case cannotLoadImage(String)
    case invalidSourceSize(Int, Int)
    case bufferInitialization(vImage_Error)
    case scaling(vImage_Error)
    case imageCreation(vImage_Error)
    case destinationCreation(String)
    case destinationFinalization(String)

    var description: String {
        switch self {
        case .invalidArguments:
            return "Usage: generate-app-icon.swift <4096-source.png> <output-directory>"
        case let .cannotLoadImage(path):
            return "Unable to load source image: \(path)"
        case let .invalidSourceSize(width, height):
            return "Source must be 4096 x 4096, got \(width) x \(height)"
        case let .bufferInitialization(error):
            return "Unable to initialize image buffer: \(error)"
        case let .scaling(error):
            return "High-quality image scaling failed: \(error)"
        case let .imageCreation(error):
            return "Unable to create output image: \(error)"
        case let .destinationCreation(path):
            return "Unable to create PNG destination: \(path)"
        case let .destinationFinalization(path):
            return "Unable to finalize PNG: \(path)"
        }
    }
}

final class RGBAImage {
    var buffer = vImage_Buffer()

    init(width: Int, height: Int) throws {
        let error = vImageBuffer_Init(
            &buffer,
            vImagePixelCount(height),
            vImagePixelCount(width),
            32,
            vImage_Flags(kvImageNoFlags)
        )
        guard error == kvImageNoError else {
            throw IconPipelineError.bufferInitialization(error)
        }
        memset(buffer.data, 0, buffer.rowBytes * height)
    }

    init(cgImage: CGImage, format: inout vImage_CGImageFormat) throws {
        let error = vImageBuffer_InitWithCGImage(
            &buffer,
            &format,
            nil,
            cgImage,
            vImage_Flags(kvImageNoFlags)
        )
        guard error == kvImageNoError else {
            throw IconPipelineError.bufferInitialization(error)
        }
    }

    deinit {
        free(buffer.data)
    }
}

func loadImage(at url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(
              source,
              0,
              [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
          ) else {
        throw IconPipelineError.cannotLoadImage(url.path)
    }
    return image
}

func scaledImage(
    from source: RGBAImage,
    width: Int,
    height: Int
) throws -> RGBAImage {
    let destination = try RGBAImage(width: width, height: height)
    var sourceBuffer = source.buffer
    var destinationBuffer = destination.buffer
    let error = vImageScale_ARGB8888(
        &sourceBuffer,
        &destinationBuffer,
        nil,
        vImage_Flags(kvImageHighQualityResampling)
    )
    guard error == kvImageNoError else {
        throw IconPipelineError.scaling(error)
    }
    return destination
}

func centeredImage(
    source: RGBAImage,
    canvasSize: Int
) throws -> RGBAImage {
    let sourceWidth = Int(source.buffer.width)
    let sourceHeight = Int(source.buffer.height)
    precondition(sourceWidth <= canvasSize && sourceHeight <= canvasSize)

    let destination = try RGBAImage(width: canvasSize, height: canvasSize)
    let xOffset = (canvasSize - sourceWidth) / 2
    let yOffset = (canvasSize - sourceHeight) / 2
    let copiedBytes = sourceWidth * 4

    for row in 0..<sourceHeight {
        let sourceRow = source.buffer.data.advanced(by: row * source.buffer.rowBytes)
        let destinationRow = destination.buffer.data.advanced(
            by: (row + yOffset) * destination.buffer.rowBytes + xOffset * 4
        )
        memcpy(destinationRow, sourceRow, copiedBytes)
    }

    return destination
}

func writePNG(
    _ image: RGBAImage,
    format: inout vImage_CGImageFormat,
    to url: URL
) throws {
    var error = kvImageNoError
    var buffer = image.buffer
    guard let unmanagedImage = vImageCreateCGImageFromBuffer(
        &buffer,
        &format,
        nil,
        nil,
        vImage_Flags(kvImageNoFlags),
        &error
    ) else {
        throw IconPipelineError.imageCreation(error)
    }
    let cgImage = unmanagedImage.takeRetainedValue()

    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IconPipelineError.destinationCreation(url.path)
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IconPipelineError.destinationFinalization(url.path)
    }
}

func appendChunkType(_ type: String, to data: inout Data) {
    precondition(type.utf8.count == 4)
    data.append(contentsOf: type.utf8)
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

func writeICNS(from outputDirectory: URL) throws {
    let representations: [(type: String, size: Int)] = [
        ("icp4", 16),
        ("icp5", 32),
        ("ic11", 32),
        ("icp6", 64),
        ("ic12", 64),
        ("ic07", 128),
        ("ic08", 256),
        ("ic13", 256),
        ("ic09", 512),
        ("ic14", 512),
        ("ic10", 1024)
    ]

    var chunks = Data()
    for representation in representations {
        let pngURL = outputDirectory.appendingPathComponent(
            "AppIcon-\(representation.size).png"
        )
        let pngData = try Data(contentsOf: pngURL)
        appendChunkType(representation.type, to: &chunks)
        appendBigEndianUInt32(UInt32(pngData.count + 8), to: &chunks)
        chunks.append(pngData)
    }

    var icns = Data()
    appendChunkType("icns", to: &icns)
    appendBigEndianUInt32(UInt32(chunks.count + 8), to: &icns)
    icns.append(chunks)
    try icns.write(
        to: outputDirectory.appendingPathComponent("AppIcon.icns"),
        options: .atomic
    )
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw IconPipelineError.invalidArguments
    }

    let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputDirectory = URL(
        fileURLWithPath: CommandLine.arguments[2],
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
    )

    let cgImage = try loadImage(at: sourceURL)
    guard cgImage.width == 4096, cgImage.height == 4096 else {
        throw IconPipelineError.invalidSourceSize(cgImage.width, cgImage.height)
    }

    let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: Unmanaged.passUnretained(colorSpace),
        bitmapInfo: CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent
    )

    let source = try RGBAImage(cgImage: cgImage, format: &format)

    // Preserve the user-approved open-state artwork footprint. The matching
    // 160 px output is also used by AppIconPreviewInApp.png.
    let dockScale = try scaledImage(from: source, width: 3328, height: 3328)
    let master = try centeredImage(source: dockScale, canvasSize: 4096)
    try writePNG(
        master,
        format: &format,
        to: outputDirectory.appendingPathComponent("AppIcon-4096.png")
    )

    let outputSizes = [2048, 1024, 512, 256, 160, 128, 64, 48, 32, 16]
    for size in outputSizes {
        // Every deliverable is generated directly from the final 4096 master.
        // No output is ever resized from another reduced image.
        let output = try scaledImage(
            from: master,
            width: size,
            height: size
        )
        try writePNG(
            output,
            format: &format,
            to: outputDirectory.appendingPathComponent("AppIcon-\(size).png")
        )
    }
    try writeICNS(from: outputDirectory)

    print("Generated high-quality app icon assets at \(outputDirectory.path)")
} catch {
    fputs("generate-app-icon: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
