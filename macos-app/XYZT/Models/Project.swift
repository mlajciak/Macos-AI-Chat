import Foundation

struct Project: Identifiable, Hashable {
    let id: String
    let name: String
}

enum ProjectCatalog {
    private static let registeredPathsKey = "xyzt.registeredProjectPaths"

    private static var userProjectsById: [String: Project] = [:]
    private static var folderURLById: [String: URL] = [:]

    static func bootstrapRegisteredFolders() {
        let paths = UserDefaults.standard.stringArray(forKey: registeredPathsKey) ?? []
        for path in paths {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            registerUserFolder(at: url, persist: false)
        }
    }

    @discardableResult
    static func registerUserFolder(at url: URL, persist: Bool = true) -> Project {
        let standardized = url.standardizedFileURL
        let id = userProjectId(for: standardized)
        let project = Project(id: id, name: standardized.lastPathComponent)
        userProjectsById[id] = project
        folderURLById[id] = standardized
        if persist {
            var paths = Set(UserDefaults.standard.stringArray(forKey: registeredPathsKey) ?? [])
            paths.insert(standardized.path)
            UserDefaults.standard.set(Array(paths).sorted(), forKey: registeredPathsKey)
        }
        return project
    }

    static func isUserProject(_ id: String) -> Bool {
        userProjectsById[id] != nil
    }

    static func folderURL(for id: String) -> URL? {
        folderURLById[id]
    }

    static func userProjects() -> [Project] {
        userProjectsById.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func project(id: String) -> Project {
        if let user = userProjectsById[id] {
            return user
        }
        return Project(id: id, name: id)
    }

    private static func userProjectId(for url: URL) -> String {
        "path:\(url.standardizedFileURL.path)"
    }
}
