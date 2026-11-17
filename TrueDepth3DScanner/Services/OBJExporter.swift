import Foundation
import UIKit

/// Exports face mesh data and real photo texture to a ZIP containing the OBJ and companion files.
/// Fully compatible with Blender, Maya, Unity, Unreal Engine, and WebGL viewers.
final class OBJExporter {

    /// Export vertices, normals, texture coordinates, triangle indices, and photo texture to a ZIP archive.
    /// Returns the URL of the generated `.zip` file, or `nil` on failure.
    static func export(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texCoords: [SIMD2<Float>],
        indices: [Int16],
        texture: UIImage? = nil
    ) -> URL? {
        let logger = LoggerService.shared

        guard !vertices.isEmpty else {
            logger.log("OBJ export failed: no vertices", level: .error)
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceScanExport_\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            logger.log("Failed to create export dir: \(error.localizedDescription)", level: .error)
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. Save texture image if present
        var hasTexture = false
        if let texture = texture, let jpegData = texture.jpegData(compressionQuality: 0.9) {
            let textureURL = tempDir.appendingPathComponent("FaceTexture.jpg")
            do {
                try jpegData.write(to: textureURL)
                hasTexture = true
            } catch {
                logger.log("Failed to save texture: \(error.localizedDescription)", level: .warning)
            }
        }

        // 2. Generate MTL file
        var mtl = "# Material definition for FaceScan\n"
        mtl += "newmtl FaceMaterial\n"
        mtl += "Ka 0.2 0.2 0.2\n"
        mtl += "Kd 0.9 0.85 0.8\n"
        mtl += "Ks 0.2 0.2 0.2\n"
        mtl += "Ns 20.0\n"
        mtl += "d 1.0\n"
        mtl += "illum 2\n"
        if hasTexture {
            mtl += "map_Kd FaceTexture.jpg\n"
        }

        let mtlURL = tempDir.appendingPathComponent("FaceScan.mtl")
        do {
            try mtl.write(to: mtlURL, atomically: true, encoding: .utf8)
        } catch {
            logger.log("Failed to write MTL: \(error.localizedDescription)", level: .error)
            return nil
        }

        // 3. Generate OBJ file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())

        var obj = "# TrueDepth 3D Face Scanner - Realistic OBJ Export\n"
        obj += "# Generated: \(dateString)\n"
        obj += "# Vertices: \(vertices.count)\n"
        obj += "# Triangles: \(indices.count / 3)\n"
        obj += "mtllib FaceScan.mtl\n"
        obj += "o FaceMesh\n\n"

        // Vertices
        for v in vertices {
            obj += String(format: "v %.6f %.6f %.6f\n", v.x, v.y, v.z)
        }
        obj += "\n"

        // Texture coordinates (UV)
        for t in texCoords {
            obj += String(format: "vt %.6f %.6f\n", t.x, 1.0 - t.y)
        }
        obj += "\n"

        // Normals
        for n in normals {
            obj += String(format: "vn %.6f %.6f %.6f\n", n.x, n.y, n.z)
        }
        obj += "\n"

        // Faces (1-based index)
        obj += "usemtl FaceMaterial\n"
        let triangleCount = indices.count / 3
        for i in 0..<triangleCount {
            let i0 = Int(indices[i * 3]) + 1
            let i1 = Int(indices[i * 3 + 1]) + 1
            let i2 = Int(indices[i * 3 + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        let objURL = tempDir.appendingPathComponent("FaceScan.obj")
        do {
            try obj.write(to: objURL, atomically: true, encoding: .utf8)
        } catch {
            logger.log("Failed to write OBJ: \(error.localizedDescription)", level: .error)
            return nil
        }

        // Keep the OBJ, MTL, and optional texture together so relative paths work after extraction.
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceScanExport_\(UUID().uuidString).zip")
        var filesToArchive = [objURL, mtlURL]
        if hasTexture {
            filesToArchive.append(tempDir.appendingPathComponent("FaceTexture.jpg"))
        }

        do {
            try ZIPStoreArchive.create(from: filesToArchive, at: zipURL)
            logger.log("OBJ archive written successfully: \(zipURL.path)", level: .info)
            return zipURL
        } catch {
            logger.log("Failed to create OBJ archive: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
}

/// Writes a small, uncompressed ZIP archive using the standard ZIP store format.
/// Face textures are already JPEG-compressed, and storing the OBJ/MTL without compression
/// keeps this export dependency-free.
private enum ZIPStoreArchive {
    private struct Entry {
        let name: Data
        let checksum: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
        let dosTime: UInt16
        let dosDate: UInt16
    }

    static func create(from fileURLs: [URL], at destinationURL: URL) throws {
        guard fileURLs.count <= Int(UInt16.max) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        var archive = Data()
        var entries = [Entry]()
        let (dosTime, dosDate) = currentDOSTimestamp()

        for fileURL in fileURLs {
            let fileData = try Data(contentsOf: fileURL)
            let fileName = Data(fileURL.lastPathComponent.utf8)
            guard fileName.count <= Int(UInt16.max),
                  fileData.count <= Int(UInt32.max),
                  archive.count <= Int(UInt32.max) else {
                throw CocoaError(.fileWriteOutOfSpace)
            }

            let checksum = crc32(fileData)
            let size = UInt32(fileData.count)
            let localHeaderOffset = UInt32(archive.count)

            archive.appendLittleEndian(UInt32(0x04034b50)) // Local file header signature
            archive.appendLittleEndian(UInt16(20))         // Version needed
            archive.appendLittleEndian(UInt16(0x0800))     // UTF-8 file names
            archive.appendLittleEndian(UInt16(0))          // Stored, no compression
            archive.appendLittleEndian(dosTime)
            archive.appendLittleEndian(dosDate)
            archive.appendLittleEndian(checksum)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(UInt16(fileName.count))
            archive.appendLittleEndian(UInt16(0))          // Extra field length
            archive.append(fileName)
            archive.append(fileData)

            entries.append(Entry(
                name: fileName,
                checksum: checksum,
                size: size,
                localHeaderOffset: localHeaderOffset,
                dosTime: dosTime,
                dosDate: dosDate
            ))
        }

        guard archive.count <= Int(UInt32.max) else {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        let centralDirectoryOffset = UInt32(archive.count)

        for entry in entries {
            archive.appendLittleEndian(UInt32(0x02014b50)) // Central directory signature
            archive.appendLittleEndian(UInt16(20))         // Version made by
            archive.appendLittleEndian(UInt16(20))         // Version needed
            archive.appendLittleEndian(UInt16(0x0800))     // UTF-8 file names
            archive.appendLittleEndian(UInt16(0))          // Stored, no compression
            archive.appendLittleEndian(entry.dosTime)
            archive.appendLittleEndian(entry.dosDate)
            archive.appendLittleEndian(entry.checksum)
            archive.appendLittleEndian(entry.size)
            archive.appendLittleEndian(entry.size)
            archive.appendLittleEndian(UInt16(entry.name.count))
            archive.appendLittleEndian(UInt16(0))          // Extra field length
            archive.appendLittleEndian(UInt16(0))          // File comment length
            archive.appendLittleEndian(UInt16(0))          // Disk number start
            archive.appendLittleEndian(UInt16(0))          // Internal file attributes
            archive.appendLittleEndian(UInt32(0))           // External file attributes
            archive.appendLittleEndian(entry.localHeaderOffset)
            archive.append(entry.name)
        }

        let centralDirectorySize = archive.count - Int(centralDirectoryOffset)
        guard centralDirectorySize <= Int(UInt32.max),
              Int(centralDirectoryOffset) + centralDirectorySize <= Int(UInt32.max) else {
            throw CocoaError(.fileWriteOutOfSpace)
        }

        archive.appendLittleEndian(UInt32(0x06054b50)) // End of central directory signature
        archive.appendLittleEndian(UInt16(0))          // Disk number
        archive.appendLittleEndian(UInt16(0))          // Central directory disk number
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt32(centralDirectorySize))
        archive.appendLittleEndian(centralDirectoryOffset)
        archive.appendLittleEndian(UInt16(0))          // Archive comment length

        try archive.write(to: destinationURL, options: .atomic)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var checksum = UInt32.max
        for byte in data {
            checksum ^= UInt32(byte)
            for _ in 0..<8 {
                checksum = (checksum & 1) == 1
                    ? (checksum >> 1) ^ 0xedb88320
                    : checksum >> 1
            }
        }
        return checksum ^ UInt32.max
    }

    private static func currentDOSTimestamp() -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let year = min(max(components.year ?? 1980, 1980), 2107) - 1980
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let time = UInt16((hour << 11) | (minute << 5) | (second / 2))
        let date = UInt16((year << 9) | (month << 5) | day)
        return (time, date)
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
