/*
 MIT License

 Copyright (c) 2023 Qonto

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import ArgumentParser
import Foundation
import PathKit
import XcodeProj

@main
struct XcodeGroupSync: ParsableCommand {
    private enum CodingKeys: String, CodingKey {
        case srcRoot
        case groupPath
        case targetName
        case pathToXcodeproj
        case pathToFiles
        case filenamePattern
    }
    
    struct Difference<T: PBXObject> {
        let filesToRemove: [T]
        private(set) var filesToAdd: [T]

        mutating func updateFilesToAdd(_ files: [T]) {
            filesToAdd = files
        }

        var hasChanges: Bool {
            !filesToRemove.isEmpty || !filesToAdd.isEmpty
        }
    }
    
    enum Error: LocalizedError {
        case invalidTargetName
        case invalidBuildPhase
        case invalidSourceFiles
        case groupNotFound
        case invalidFilePath
        case unableToFindRootFolder
        case invalidFilenamePattern(Swift.Error)
    }
    @Option(name: .customLong("src-root"), help: "$(SRC_ROOT) folder of the project")
    var srcRoot: String

    @Option(name: .customLong("group-path"), help: #"Path to location of the group in project hierarchy, which would be used to locate the files' group within the `.pbxproj`"#)
    var groupPath: String

    @Option(name: .long, help: "Target name to which files would get assigned as compilable sources")
    var targetName: String

    @Option(name: .customLong("path-to-xcodeproj"), help: "Custom .xcodeproj file location relative to `src-root` argument")
    var pathToXcodeproj: String

    @Option(name: .customLong("path-to-files"), help: "Custom path to files' folder relative to `group-path` argument")
    var pathToFiles: String

    @Option(name: .customLong("filename-pattern"), help: "Regex pattern for filenames to match in build phase (i.e. `*.generated.swift`)")
    var filenamePattern: String

    private var root: Path {
        return Path(srcRoot + groupPath)
    }

    private var absolutePathToFiles: Path {
        Path(srcRoot + groupPath + pathToFiles)
    }

    private var pbxprojPath: Path {
        guard pathToXcodeproj.isEmpty else {
            return Path(srcRoot + pathToXcodeproj)
        }
        return root + .Element("\(root.lastComponent + ".xcodeproj")")
    }

    static let configuration = CommandConfiguration(
        abstract: "A Swift command-line tool for adjusting files on disk with a group in the specified target."
    )

    mutating func run() throws {
        do {
            let project = try XcodeProj(path: pbxprojPath)

            // Find the needed PBXGroup
            let allGroups = project.pbxproj.groups

            guard let relatedGroup = allGroups.first(where: { (try? $0.fullPath(sourceRoot: .Element("/")))?.string == groupPath + pathToFiles })
            else { throw XcodeGroupSync.Error.groupNotFound }

            // Detect files from file system
            let newFileReferences = try absolutePathToFiles.children()
                .filter { $0.extension == "swift" }
                .map {
                    let element = PBXFileElement(sourceTree: .group, path: $0.lastComponent)
                    element.parent = relatedGroup
                    return element
                }

            // update Group
            let oldFileReferences = relatedGroup.children

            var groupDifference = delta(betweenNewFileReferences: newFileReferences, oldFileReferences: oldFileReferences)
            try update(group: relatedGroup, difference: &groupDifference)
            // Update PBXBuildPhase
            guard let target = project.pbxproj.nativeTargets.first(where: { $0.name.caseInsensitiveCompare(targetName) == .orderedSame })
            else {
                throw XcodeGroupSync.Error.invalidTargetName
            }
            
            guard let sourcesBuildPhase = try target.sourcesBuildPhase() else {
                throw XcodeGroupSync.Error.invalidBuildPhase
            }
            guard let allBuildFileReferences = sourcesBuildPhase.files?.compactMap(\.file)
            else {
                throw XcodeGroupSync.Error.invalidSourceFiles
            }
            let oldBuildPhaseFileReferences = try allBuildFileReferences.filter {
                guard let path = $0.path
                else { return false }

                do {
                    let regex: Regex = try Regex(filenamePattern)
                    return try regex.firstMatch(in: path) != nil
                } catch {
                    throw XcodeGroupSync.Error.invalidFilenamePattern(error)
                }
            }

            var phaseDifference = delta(betweenNewFileReferences: newFileReferences, oldFileReferences: oldBuildPhaseFileReferences)
            // TODO: updating phase files' "filesToAdd" based on group files' "filesToAdd"
            // in order to rely on physical appearance of group as a single source of truth, and not what was the actual difference
            // between "build phase" file references and "on the disk" file references.
            // This might lead to wrong behaviour if and only if files were added to Build Phase, but not to the group,
            // which is essentially a wrong action. But this logic should fallback correctly anyway, thus leaving this comment.
            phaseDifference.updateFilesToAdd(groupDifference.filesToAdd)
            try update(buildPhase: sourcesBuildPhase, difference: phaseDifference)

            // Update XcodeProj object in case of leftovers
            update(project: project, phaseDifference: phaseDifference)

            if groupDifference.hasChanges || phaseDifference.hasChanges {
                try project.write(path: pbxprojPath)
                Swift.print("✅ Successfully processed files for \(targetName).")
            } else {
                Swift.print("💨 Skipping processing files for \(targetName).")
            }
        } catch {
            XcodeGroupSync.exit(withError: error)
        }
    }

    func update(project: XcodeProj, phaseDifference: Difference<PBXFileElement>) {
        // Remove all leftover references from PBXProj object in case group & build phase cleanup left something behind
        let references = project.pbxproj.fileReferences
        let toRemove = references.filter { reference in
            phaseDifference.filesToRemove.first { toRemove in
                reference.uuid == toRemove.uuid
            } != nil
        }
        toRemove.forEach(project.pbxproj.delete(object:))
    }

    func update(buildPhase: PBXBuildPhase, difference: Difference<PBXFileElement>) throws {
        if !difference.filesToRemove.isEmpty,
           var files = buildPhase.files {
            files.removeAll { buildFile in
                difference.filesToRemove.first { toRemove in
                    // it is safe to use uuid for comparison when removing existing references
                    toRemove.uuid == buildFile.file?.uuid
                } != nil
            }
            buildPhase.files = files
        }

        for buildFile in difference.filesToAdd {
            _ = try buildPhase.add(file: buildFile)
        }
    }

    func update(group: PBXGroup, difference: inout Difference<PBXFileElement>) throws {
        if !difference.filesToRemove.isEmpty {
            var children = group.children
            children.removeAll(where: { child in
                difference.filesToRemove.first { toRemove in
                    // it is safe to use uuid for comparison when removing existing references
                    child.uuid == toRemove.uuid
                } != nil
            })
            group.children = children
        }

        var addedFiles: [PBXFileElement] = []
        for fileReference in difference.filesToAdd {
            guard let fullFilePath = try? fileReference.fullPath(sourceRoot: srcRoot) else {
                throw XcodeGroupSync.Error.invalidFilePath
            }
            let newFile = try group.addFile(
                at: Path(fullFilePath),
                sourceRoot: Path(srcRoot),
                override: false
            )
            addedFiles.append(newFile)
        }

        if !addedFiles.isEmpty {
            difference.updateFilesToAdd(addedFiles)
        }
    }

    func delta<T: PBXFileElement>(betweenNewFileReferences newFiles: [T], oldFileReferences oldFiles: [T]) -> Difference<T> {
        // newFiles: [A, B, C] vs. oldFiles: [A, C, D]
        // toRemove: [D]
        // toAdd: [B]

        // newFiles: [A, B, C, D, E, F, G] vs. oldFiles: [A, B, X, Y, Z]
        // toRemove: [X, Y, Z]
        // toAdd: [C, D, E, F, G]

        var toRemove = oldFiles
        var toAdd = newFiles
        toRemove.removeAll(where: { oldFile in
            newFiles.contains(where: { $0.path == oldFile.path })
        })

        toAdd.removeAll(where: { newFile in
            oldFiles.contains(where: { $0.path == newFile.path })
        })
        return .init(filesToRemove: toRemove, filesToAdd: toAdd)
    }
}
