import Foundation

struct ZipWriter {
    struct Entry {
        let path: String
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    static func zipFolder(at sourceFolderURL: URL, to zipFileURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: zipFileURL.path) {
            try fm.removeItem(at: zipFileURL)
        }

        let parent = zipFileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        fm.createFile(atPath: zipFileURL.path, contents: nil)
        let zipHandle = try FileHandle(forWritingTo: zipFileURL)
        defer {
            try? zipHandle.close()
        }

        let sourceFolder = sourceFolderURL.standardizedFileURL
        let sourcePathPrefix = sourceFolder.path.hasSuffix("/") ? sourceFolder.path : (sourceFolder.path + "/")

        var outputOffset: UInt32 = 0
        var entries: [Entry] = []

        let enumerator = fm.enumerator(
            at: sourceFolder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let next = enumerator?.nextObject() {
            guard let fileURL = next as? URL else { continue }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let fullPath = fileURL.standardizedFileURL.path
            guard fullPath.hasPrefix(sourcePathPrefix) else { continue }
            let relativePath = String(fullPath.dropFirst(sourcePathPrefix.count))

            let filenameData = Data(relativePath.utf8)
            let flags: UInt16 = 0x0008 | 0x0800 // data descriptor + UTF-8
            let compression: UInt16 = 0 // stored

            let localHeaderOffset = outputOffset
            var localHeader = Data()
            localHeader.appendUInt32(0x04034b50)
            localHeader.appendUInt16(20)
            localHeader.appendUInt16(flags)
            localHeader.appendUInt16(compression)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt32(0)
            localHeader.appendUInt32(0)
            localHeader.appendUInt32(0)
            localHeader.appendUInt16(UInt16(filenameData.count))
            localHeader.appendUInt16(0)
            localHeader.append(filenameData)

            try zipHandle.write(contentsOf: localHeader)
            outputOffset &+= UInt32(localHeader.count)

            let fileReadHandle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? fileReadHandle.close()
            }

            var runningCRC: UInt32 = 0xFFFF_FFFF
            var size: UInt32 = 0

            while true {
                let chunk = try fileReadHandle.read(upToCount: 64 * 1024) ?? Data()
                if chunk.isEmpty { break }

                chunk.withUnsafeBytes { raw in
                    runningCRC = CRC32.update(runningCRC, with: raw)
                }

                try zipHandle.write(contentsOf: chunk)
                outputOffset &+= UInt32(chunk.count)
                size &+= UInt32(chunk.count)
            }

            let crc32 = runningCRC ^ 0xFFFF_FFFF

            var descriptor = Data()
            descriptor.appendUInt32(0x08074b50)
            descriptor.appendUInt32(crc32)
            descriptor.appendUInt32(size)
            descriptor.appendUInt32(size)

            try zipHandle.write(contentsOf: descriptor)
            outputOffset &+= UInt32(descriptor.count)

            entries.append(
                Entry(
                    path: relativePath,
                    crc32: crc32,
                    compressedSize: size,
                    uncompressedSize: size,
                    localHeaderOffset: localHeaderOffset
                )
            )
        }

        let centralDirectoryOffset = outputOffset
        var centralDirectorySize: UInt32 = 0

        for entry in entries {
            let filenameData = Data(entry.path.utf8)
            let flags: UInt16 = 0x0008 | 0x0800
            let compression: UInt16 = 0

            var header = Data()
            header.appendUInt32(0x02014b50)
            header.appendUInt16(20)
            header.appendUInt16(20)
            header.appendUInt16(flags)
            header.appendUInt16(compression)
            header.appendUInt16(0)
            header.appendUInt16(0)
            header.appendUInt32(entry.crc32)
            header.appendUInt32(entry.compressedSize)
            header.appendUInt32(entry.uncompressedSize)
            header.appendUInt16(UInt16(filenameData.count))
            header.appendUInt16(0)
            header.appendUInt16(0)
            header.appendUInt16(0)
            header.appendUInt16(0)
            header.appendUInt32(0)
            header.appendUInt32(entry.localHeaderOffset)
            header.append(filenameData)

            try zipHandle.write(contentsOf: header)
            outputOffset &+= UInt32(header.count)
            centralDirectorySize &+= UInt32(header.count)
        }

        var eocd = Data()
        eocd.appendUInt32(0x06054b50)
        eocd.appendUInt16(0)
        eocd.appendUInt16(0)
        eocd.appendUInt16(UInt16(entries.count))
        eocd.appendUInt16(UInt16(entries.count))
        eocd.appendUInt32(centralDirectorySize)
        eocd.appendUInt32(centralDirectoryOffset)
        eocd.appendUInt16(0)

        try zipHandle.write(contentsOf: eocd)
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        var out: [UInt32] = []
        out.reserveCapacity(256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) == 1 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c >>= 1
                }
            }
            out.append(c)
        }
        return out
    }()

    static func update(_ crc: UInt32, with buffer: UnsafeRawBufferPointer) -> UInt32 {
        var c = crc
        for b in buffer {
            let idx = Int((c ^ UInt32(b)) & 0xFF)
            c = table[idx] ^ (c >> 8)
        }
        return c
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
