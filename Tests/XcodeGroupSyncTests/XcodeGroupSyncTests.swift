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

import XCTest
import XcodeProj
@testable import XcodeGroupSync

final class XcodeGroupSyncTests: XCTestCase {

    func test_difference_whenReferencesAreSame_hasChanges_shouldReturnFalse() throws {
        // GIVEN
        // WHEN
        let command = try XCTUnwrap(
            XcodeGroupSync.parseAsRoot([
                "--src-root",
                "",
                "--group-path",
                "",
                "--target-name",
                "",
                "--path-to-xcodeproj",
                "",
                "--path-to-files",
                "",
                "--filename-pattern",
                ""
            ]) as? XcodeGroupSync)

        // THEN
        let references = [PBXFileElement(path: "a"), PBXFileElement(path: "b"), PBXFileElement(path: "c")]
        let oldReferences = [PBXFileElement(path: "c"), PBXFileElement(path: "b"), PBXFileElement(path: "a")]
        let delta = command.delta(betweenNewFileReferences: references, oldFileReferences: oldReferences)
        XCTAssertFalse(delta.hasChanges)
    }

    func test_difference_whenReferencesAreSame_hasChanges_shouldReturnTrue() throws {
        // GIVEN
        // WHEN
        let command = try XCTUnwrap(
            XcodeGroupSync.parseAsRoot([
                "--src-root",
                "",
                "--group-path",
                "",
                "--target-name",
                "",
                "--path-to-xcodeproj",
                "",
                "--path-to-files",
                "",
                "--filename-pattern",
                ""
            ]) as? XcodeGroupSync)

        // THEN
        let references = [PBXFileElement(path: "d"), PBXFileElement(path: "z"), PBXFileElement(path: "c")]
        let oldReferences = [PBXFileElement(path: "c"), PBXFileElement(path: "b"), PBXFileElement(path: "a")]
        let delta = command.delta(betweenNewFileReferences: references, oldFileReferences: oldReferences)
        XCTAssertTrue(delta.hasChanges)
    }

    func test_difference_whenReferencesAreSame_hasExpectedFilesToAdd() throws {
        // GIVEN
        // WHEN
        let command = try XCTUnwrap(
            XcodeGroupSync.parseAsRoot([
                "--src-root",
                "",
                "--group-path",
                "",
                "--target-name",
                "",
                "--path-to-xcodeproj",
                "",
                "--path-to-files",
                "",
                "--filename-pattern",
                ""
            ]) as? XcodeGroupSync)

        // THEN
        let difference = [PBXFileElement(path: "d"), PBXFileElement(path: "z")]
        let references = [PBXFileElement(path: "d"), PBXFileElement(path: "z"), PBXFileElement(path: "c")]
        let oldReferences = [PBXFileElement(path: "c"), PBXFileElement(path: "b"), PBXFileElement(path: "a")]
        let delta = command.delta(betweenNewFileReferences: references, oldFileReferences: oldReferences)
        XCTAssertEqual(delta.filesToAdd, difference)
    }

    func test_difference_whenReferencesAreSame_hasExpectedFilesToRemove() throws {
        // GIVEN
        // WHEN
        let command = try XCTUnwrap(
            XcodeGroupSync.parseAsRoot([
                "--src-root",
                "",
                "--group-path",
                "",
                "--target-name",
                "",
                "--path-to-xcodeproj",
                "",
                "--path-to-files",
                "",
                "--filename-pattern",
                ""
            ]) as? XcodeGroupSync)

        // THEN
        let difference = [PBXFileElement(path: "d"), PBXFileElement(path: "z")]
        let references = [PBXFileElement(path: "d"), PBXFileElement(path: "z"), PBXFileElement(path: "c")]
        let oldReferences = [PBXFileElement(path: "c"), PBXFileElement(path: "b"), PBXFileElement(path: "a")]
        let delta = command.delta(betweenNewFileReferences: oldReferences, oldFileReferences: references)
        XCTAssertEqual(delta.filesToRemove, difference)
    }
}
