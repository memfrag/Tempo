import SwiftUI

@MainActor @Observable
final class AppState {
    var client: NokoClient?
    var user: NokoUser?
    var projects: [NokoProject] = []
    var isAuthenticated = false
    var isLoading = false
    var error: String?

    // Preferences
    var defaultProjectId: Int? = nil {
        didSet { UserDefaults.standard.set(defaultProjectId, forKey: "defaultProjectId") }
    }

    var showMenuBarWidget: Bool {
        get { UserDefaults.standard.bool(forKey: "showMenuBarWidget") }
        set { UserDefaults.standard.set(newValue, forKey: "showMenuBarWidget") }
    }

    var sidebarProjectIds: [Int] = [] {
        didSet { UserDefaults.standard.set(sidebarProjectIds, forKey: "sidebarProjectIds") }
    }

    var sidebarProjects: [NokoProject] {
        let selectedIds = Set(sidebarProjectIds)
        return projects.filter { selectedIds.contains($0.id) }
    }

    var currentUserId: Int? { user?.id }

    var defaultProject: NokoProject? {
        guard let id = defaultProjectId else { return projects.first }
        return projects.first(where: { $0.id == id }) ?? projects.first
    }

    func addSidebarProject(_ project: NokoProject) {
        if !sidebarProjectIds.contains(project.id) {
            sidebarProjectIds.append(project.id)
        }
    }

    func removeSidebarProject(_ project: NokoProject) {
        sidebarProjectIds.removeAll { $0 == project.id }
    }

    private static var projectsCacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tempoDir = appSupport.appendingPathComponent("Tempo", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempoDir, withIntermediateDirectories: true)
        return tempoDir.appendingPathComponent("projects_cache.json")
    }

    init() {
        if UserDefaults.standard.object(forKey: "showMenuBarWidget") == nil {
            UserDefaults.standard.set(true, forKey: "showMenuBarWidget")
        }
        self.sidebarProjectIds = UserDefaults.standard.array(forKey: "sidebarProjectIds") as? [Int] ?? []
        self.defaultProjectId = UserDefaults.standard.object(forKey: "defaultProjectId") as? Int
        self.projects = Self.loadCachedProjects()
    }

    func configure(token: String) async throws {
        let newClient = NokoClient(token: token)
        let user = try await newClient.currentUser()
        try KeychainHelper.save(token: token)
        self.client = newClient
        self.user = user
        self.isAuthenticated = true
        try await loadProjects()
    }

    func restoreSession() async {
        guard let token = KeychainHelper.load() else { return }
        let newClient = NokoClient(token: token)
        do {
            let user = try await newClient.currentUser()
            self.client = newClient
            self.user = user
            self.isAuthenticated = true
            // Refresh projects in the background — cached ones are already loaded from init
            Task { try? await loadProjects() }
        } catch {
            // Token invalid or network issue — stay on onboarding
            self.isAuthenticated = false
        }
    }

    func loadProjects() async throws {
        guard let client else { return }
        let fetched = try await client.projects()
        self.projects = fetched
        Self.cacheProjects(fetched)
    }

    private static func loadCachedProjects() -> [NokoProject] {
        guard let data = try? Data(contentsOf: projectsCacheURL) else { return [] }
        return (try? JSONDecoder().decode([NokoProject].self, from: data)) ?? []
    }

    private static func cacheProjects(_ projects: [NokoProject]) {
        if let data = try? JSONEncoder().encode(projects) {
            try? data.write(to: projectsCacheURL, options: .atomic)
        }
    }

    func logout() {
        KeychainHelper.delete()
        client = nil
        user = nil
        projects = []
        isAuthenticated = false
    }
}
