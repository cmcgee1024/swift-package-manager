//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Dispatch
import struct TSCBasic.FileSystemError

#if os(Windows)
import WinSDK
#endif

/// An `Archiver` that handles ZIP archives using the command-line `zip` and `unzip` tools.
public struct ZipArchiver: Archiver, Cancellable {
    public var supportedExtensions: Set<String> { ["zip"] }

    /// The file-system implementation used for various file-system operations and checks.
    private let fileSystem: FileSystem

    /// Helper for cancelling in-flight requests
    private let cancellator: Cancellator

    /// Absolute path to the Windows tar in the system folder
    #if os(Windows)
        internal let windowsTar: String
    #else
        internal let unzip = "unzip"
        internal let zip = "zip"
    #endif

    #if os(FreeBSD)
        internal let tar = "tar"
    #endif

    /// Creates a `ZipArchiver`.
    ///
    /// - Parameters:
    ///   - fileSystem: The file-system to be used by the `ZipArchiver`.
    ///   - cancellator: Cancellation handler
    public init(fileSystem: FileSystem, cancellator: Cancellator? = .none) {
        self.fileSystem = fileSystem
        self.cancellator = cancellator ?? Cancellator(observabilityScope: .none)

        #if os(Windows)
        var tarPath: PWSTR?
        defer { CoTaskMemFree(tarPath) }
        let hr = withUnsafePointer(to: FOLDERID_System) { id in
            SHGetKnownFolderPath(id, DWORD(KF_FLAG_DEFAULT.rawValue), nil, &tarPath)
        }
        if hr == S_OK, let tarPath {
            windowsTar = String(decodingCString: tarPath, as: UTF16.self) + "\\tar.exe"
        } else {
            windowsTar = "tar.exe"
        }
        #endif
    }

    public func extract(
        from archivePath: AbsolutePath,
        to destinationPath: AbsolutePath,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        do {
            guard self.fileSystem.exists(archivePath) else {
                throw FileSystemError(.noEntry, archivePath.underlying)
            }

            guard self.fileSystem.isDirectory(destinationPath) else {
                throw FileSystemError(.notDirectory, destinationPath.underlying)
            }

            #if os(Windows)
            // FileManager lost the ability to detect tar.exe as executable.
            // It's part of system32 anyway so use the absolute path.
            let process = AsyncProcess(arguments: [windowsTar, "xf", archivePath.pathString, "-C", destinationPath.pathString])
            #else
                let process = AsyncProcess(arguments: [
                    self.unzip, archivePath.pathString, "-d", destinationPath.pathString,
                ])
            #endif
            guard let registrationKey = self.cancellator.register(process) else {
                throw CancellationError.failedToRegisterProcess(process)
            }

            DispatchQueue.sharedConcurrent.async {
                defer { self.cancellator.deregister(registrationKey) }
                completion(.init(catching: {
                    try process.launch()
                    let processResult = try process.waitUntilExit()
                    guard processResult.exitStatus == .terminated(code: 0) else {
                        throw try StringError(processResult.utf8stderrOutput())
                    }
                }))
            }
        } catch {
            return completion(.failure(error))
        }
    }

    public func compress(
        directory: AbsolutePath,
        to destinationPath: AbsolutePath
    ) async throws {
        guard self.fileSystem.isDirectory(directory) else {
            throw FileSystemError(.notDirectory, directory.underlying)
        }

        #if os(Windows)
        let process = AsyncProcess(
            // FIXME: are these the right arguments?
            arguments: [windowsTar, "-a", "-c", "-f", destinationPath.pathString, directory.basename],
            workingDirectory: directory.parentDirectory
        )
        #elseif os(FreeBSD)
        // On FreeBSD, the unzip command is available in base but not the zip command.
        // Therefore; we use libarchive(bsdtar) to produce the ZIP archive instead.
        let process = AsyncProcess(
                arguments: [
                    self.tar, "-c", "--format", "zip", "-f", destinationPath.pathString,
                    directory.basename,
                ],
          workingDirectory: directory.parentDirectory
        )
        #else
        // This is to work around `swift package-registry publish` tool failing on
        // Amazon Linux 2 due to it having an earlier Glibc version (rdar://116370323)
        // and therefore posix_spawn_file_actions_addchdir_np is unavailable.
        // Instead of passing `workingDirectory` param to TSC.Process, which will trigger
        // SPM_posix_spawn_file_actions_addchdir_np_supported check, we shell out and
        // do `cd` explicitly before `zip`.
        let process = AsyncProcess(
            arguments: [
                "/bin/sh",
                "-c",
                    "cd \(directory.parentDirectory.underlying.pathString) && \(self.zip) -ry \(destinationPath.pathString) \(directory.basename)"
            ]
        )
        #endif

        guard let registrationKey = self.cancellator.register(process) else {
            throw CancellationError.failedToRegisterProcess(process)
        }

        defer { self.cancellator.deregister(registrationKey) }

        try process.launch()
        let processResult = try await process.waitUntilExit()
        guard processResult.exitStatus == .terminated(code: 0) else {
            throw try StringError(processResult.utf8stderrOutput())
        }
    }

    public func validate(path: AbsolutePath, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        do {
            guard self.fileSystem.exists(path) else {
                throw FileSystemError(.noEntry, path.underlying)
            }

            #if os(Windows)
            let process = AsyncProcess(arguments: [windowsTar, "tf", path.pathString])
            #else
                let process = AsyncProcess(arguments: [self.unzip, "-t", path.pathString])
            #endif
            guard let registrationKey = self.cancellator.register(process) else {
                throw CancellationError.failedToRegisterProcess(process)
            }

            DispatchQueue.sharedConcurrent.async {
                defer { self.cancellator.deregister(registrationKey) }
                completion(.init(catching: {
                    try process.launch()
                    let processResult = try process.waitUntilExit()
                    return processResult.exitStatus == .terminated(code: 0)
                }))
            }
        } catch {
            return completion(.failure(error))
        }
    }

    public func cancel(deadline: DispatchTime) throws {
        try self.cancellator.cancel(deadline: deadline)
    }
}
