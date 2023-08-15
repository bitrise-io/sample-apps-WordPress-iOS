import Foundation

/// Manages dashboard settings such as card visibility.
struct BlogDashboardPersonalizationService {
    private enum Constants {
        static let siteAgnosticVisibilityKey = "siteAgnosticVisibilityKey"
    }

    private let repository: UserPersistentRepository
    private let siteID: String

    init(repository: UserPersistentRepository = UserDefaults.standard,
         siteID: Int) {
        self.repository = repository
        self.siteID = String(siteID)
    }

    func isEnabled(_ card: DashboardCard) -> Bool {
        let settings = getSettings(for: card)

        return (settings[Constants.siteAgnosticVisibilityKey] ?? true) && (settings[siteID] ?? true)
    }

    func hasPreference(for card: DashboardCard) -> Bool {
        getSettings(for: card)[siteID] != nil
    }

    /// Sets the enabled state for a given DashboardCard.
    ///
    /// This function updates the enabled state of a `DashboardCard`. Depending on the `forAllSites` flag,
    /// it either sets the state for a specific site or sets it agnostically for all sites. After updating
    /// the settings, a notification is posted to inform other parts of the application about this change.
    ///
    /// - Parameters:
    ///   - isEnabled: A Boolean value indicating whether the `DashboardCard` should be enabled or disabled.
    ///   - card: The `DashboardCard` whose setting needs to be updated.
    ///   - forAllSites: A Boolean flag that determines if the setting should be applied site-agnostically.
    ///                  Default is `false`, meaning the setting will be applied for a specific site.
    ///                  If set to `true`, the setting will be applied irrespective of the site.
    func setEnabled(_ isEnabled: Bool, for card: DashboardCard, forAllSites: Bool = false) {
        guard let key = makeKey(for: card) else { return }
        var settings = getSettings(for: card)

        let keyValue = forAllSites ? Constants.siteAgnosticVisibilityKey : siteID
        settings[keyValue] = isEnabled

        repository.set(settings, forKey: key)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .blogDashboardPersonalizationSettingsChanged, object: self)
        }
    }

    private func getSettings(for card: DashboardCard) -> [String: Bool] {
        guard let key = makeKey(for: card) else { return [:] }
        return repository.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }
}

private func makeKey(for card: DashboardCard) -> String? {
    switch card {
    case .todaysStats:
        return "todays-stats-card-enabled-site-settings"
    case .draftPosts:
        return "draft-posts-card-enabled-site-settings"
    case .scheduledPosts:
        return "scheduled-posts-card-enabled-site-settings"
    case .blaze:
        return "blaze-card-enabled-site-settings"
    case .prompts:
        // Warning: there is an irregularity with the prompts key that doesn't
        // have a "-card" component in the key name. Keeping it like this to
        // avoid having to migrate data.
        return "prompts-enabled-site-settings"
    case .domainsDashboardCard:
        return "domains-dashboard-card-enabled-site-settings"
    case .freeToPaidPlansDashboardCard:
        return "free-to-paid-plans-dashboard-card-enabled-site-settings"
    case .domainRegistration:
        return "register-domain-dashboard-card"
    case .googleDomains:
        return "google-domains-card-enabled-site-settings"
    case .activityLog:
        return "activity-log-card-enabled-site-settings"
    case .pages:
        return "pages-card-enabled-site-settings"
    case .quickStart:
        return "quick-start-card-enabled-site-settings"
    case .jetpackBadge, .jetpackInstall, .jetpackSocial, .failure, .ghost, .personalize, .empty:
        return nil
    }
}

extension NSNotification.Name {
    /// Sent whenever any of the blog settings managed by ``BlogDashboardPersonalizationService``
    /// are changed.
    static let blogDashboardPersonalizationSettingsChanged = NSNotification.Name("BlogDashboardPersonalizationSettingsChanged")
}
