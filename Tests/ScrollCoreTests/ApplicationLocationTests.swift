import Foundation
import ScrollCore

struct ApplicationLocationTests {
    private let directories = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/Users/tester/Applications")]

    func allowsSystemAndUserApplicationsDirectories() throws {
        for path in ["/Applications/BigBigMouse.app", "/Applications/Utilities/BigBigMouse.app", "/Users/tester/Applications/BigBigMouse.app"] {
            try expect(ApplicationLocation.isInstalled(URL(fileURLWithPath: path), in: directories))
        }
    }

    func rejectsDownloadsDiskImagesBuildsAndPrefixLookalikes() throws {
        for path in ["/Users/tester/Downloads/BigBigMouse.app", "/Volumes/BigBigMouse/BigBigMouse.app", "/work/dist/0.1.2/BigBigMouse.app", "/Applications-copy/BigBigMouse.app", "/Applications/../Downloads/BigBigMouse.app", "/Applications"] {
            try expect(!ApplicationLocation.isInstalled(URL(fileURLWithPath: path), in: directories))
        }
        try expect(!ApplicationLocation.isInstalled(URL(string: "https://example.com/Applications/BigBigMouse.app")!, in: directories))
    }

    func symbolicLinkDoesNotDisguiseAnExternalCopyAsInstalled() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let installed = root.appendingPathComponent("Applications")
        let external = root.appendingPathComponent("Downloads/BigBigMouse.app")
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let link = installed.appendingPathComponent("BigBigMouse.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
        try expect(!ApplicationLocation.isInstalled(link, in: [installed]))
        try expect(ApplicationLocation.isSameCopy(link, external))
    }

    func distinguishesInstalledAndBuildCopiesWithTheSameName() throws {
        let installed = URL(fileURLWithPath: "/Applications/BigBigMouse.app")
        let build = URL(fileURLWithPath: "/work/dist/0.1.2/BigBigMouse.app")
        try expect(!ApplicationLocation.isSameCopy(installed, build))
        try expect(ApplicationLocation.isSameCopy(installed, URL(fileURLWithPath: "/Applications/Utilities/../BigBigMouse.app")))
    }

    func validatesRelaunchParentBeforeWaiting() throws {
        try expect(RelaunchRequest.parentProcessID(in: ["BigBigMouse", "--relaunch-after", "42"]) == 42)
        for arguments in [["BigBigMouse"], ["--relaunch-after"], ["--relaunch-after", "zero"], ["--relaunch-after", "0"], ["--relaunch-after", "-1"], ["--relaunch-after", "999999999999"], ["--relaunch-after", "--allow-development-location"]] {
            try expect(RelaunchRequest.parentProcessID(in: arguments) == nil)
        }
    }
}
