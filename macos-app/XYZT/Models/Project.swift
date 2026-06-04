import Foundation

struct Project: Identifiable, Hashable {
    let id: String
    let name: String
}

enum ProjectCatalog {
    static let demo: [Project] = [
        Project(id: "bracket-v2", name: "bracket-v2"),
        Project(id: "sensor-board", name: "sensor-board"),
        Project(id: "demo-folder", name: "demo-folder"),
    ]

    static let defaultProject = demo[0]

    private static var userProjectsById: [String: Project] = [:]

    @discardableResult
    static func registerUserFolder(at url: URL) -> Project {
        let id = userProjectId(for: url)
        let project = Project(id: id, name: url.lastPathComponent)
        userProjectsById[id] = project
        return project
    }

    static func project(id: String) -> Project {
        if let user = userProjectsById[id] {
            return user
        }
        return demo.first { $0.id == id } ?? defaultProject
    }

    private static func userProjectId(for url: URL) -> String {
        "path:\(url.standardizedFileURL.path)"
    }
}
