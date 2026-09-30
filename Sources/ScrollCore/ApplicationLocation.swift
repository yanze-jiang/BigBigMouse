import Foundation

public enum ApplicationLocation {
    public static func isInstalled(_ app: URL, in directories: [URL]) -> Bool {
        guard app.isFileURL, app.pathExtension.lowercased() == "app" else { return false }
        let components = canonical(app).pathComponents
        return directories.contains { directory in
            guard directory.isFileURL else { return false }
            let root = canonical(directory).pathComponents
            return components.count > root.count && components.starts(with: root)
        }
    }

    public static func isSameCopy(_ first: URL, _ second: URL) -> Bool {
        first.isFileURL && second.isFileURL && canonical(first) == canonical(second)
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}

public enum RelaunchRequest {
    public static func parentProcessID(in arguments: [String]) -> Int32? {
        guard let index = arguments.firstIndex(of: "--relaunch-after"),
              arguments.indices.contains(index + 1),
              let pid = Int32(arguments[index + 1]), pid > 0
        else { return nil }
        return pid
    }
}
