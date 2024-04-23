import Foundation
import Combine
import WordPressKit

protocol StatsSubscribersStoreProtocol {
    var emailsSummary: CurrentValueSubject<StatsSubscribersStore.State<StatsEmailsSummaryData>, Never> { get }
    var subscribersList: CurrentValueSubject<StatsSubscribersStore.State<[StatsFollower]>, Never> { get }

    func updateEmailsSummary(quantity: Int, sortField: StatsEmailsSummaryData.SortField)
    func updateSubscribersList(quantity: Int)
}

struct StatsSubscribersStore: StatsSubscribersStoreProtocol {
    private let siteID: NSNumber
    private let cache: StatsSubscribersCache = .shared
    private let statsService: StatsServiceRemoteV2

    var emailsSummary: CurrentValueSubject<State<StatsEmailsSummaryData>, Never> = .init(.idle)
    var subscribersList: CurrentValueSubject<State<[StatsFollower]>, Never> = .init(.idle)

    init() {
        self.siteID = SiteStatsInformation.sharedInstance.siteID ?? 0
        let timeZone = SiteStatsInformation.sharedInstance.siteTimeZone ?? .current
        let wpApi = WordPressComRestApi.defaultApi(oAuthToken: SiteStatsInformation.sharedInstance.oauth2Token, userAgent: WPUserAgent.wordPress())
        statsService = StatsServiceRemoteV2(wordPressComRestApi: wpApi, siteID: siteID.intValue, siteTimezone: timeZone)
    }

    // MARK: - Emails Summary

    func updateEmailsSummary(quantity: Int, sortField: StatsEmailsSummaryData.SortField) {
        guard emailsSummary.value != .loading else { return }

        let sortOrder = StatsEmailsSummaryData.SortOrder.descending
        let cacheKey = StatsSubscribersCache.CacheKey.emailsSummary(quantity: quantity, sortField: sortField.rawValue, sortOrder: sortOrder.rawValue, siteId: siteID)
        let cachedData: StatsEmailsSummaryData? = cache.getValue(key: cacheKey)

        if let cachedData = cachedData {
            self.emailsSummary.send(.success(cachedData))
        } else {
            emailsSummary.send(.loading)
        }

        statsService.getData(quantity: quantity, sortField: sortField, sortOrder: sortOrder) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    cache.setValue(data, key: cacheKey)
                    self.emailsSummary.send(.success(data))
                case .failure:
                    if cachedData == nil {
                        self.emailsSummary.send(.error)
                    }
                }
            }
        }
    }

    // MARK: - Subscribers List

    func updateSubscribersList(quantity: Int) {
        let cacheKey = StatsSubscribersCache.CacheKey.subscribersList(quantity: quantity, siteId: siteID)
        let cachedData: [StatsFollower]? = cache.getValue(key: cacheKey)

        if let cachedData = cachedData {
            self.subscribersList.send(.success(cachedData))
        } else {
            subscribersList.send(.loading)
        }

        getSubscribers(quantity: quantity) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    cache.setValue(data, key: cacheKey)
                    self.subscribersList.send(.success(data))
                case .failure:
                    if cachedData == nil {
                        self.subscribersList.send(.error)
                    }
                }
            }
        }
    }

    private func getSubscribers(quantity: Int, completion: @escaping (Result<[StatsFollower], Error>) -> Void) {
        let group = DispatchGroup()
        var followers: [StatsFollower] = []
        var requestError: Error?

        group.enter()
        statsService.getInsight(limit: quantity) { (wpComFollowers: StatsDotComFollowersInsight?, error) in
            followers.append(contentsOf: wpComFollowers?.topDotComFollowers ?? [])
            requestError = error
            group.leave()
        }

        group.enter()
        statsService.getInsight(limit: quantity) { (wpComFollowers: StatsEmailFollowersInsight?, error) in
            followers.append(contentsOf: wpComFollowers?.topEmailFollowers ?? [])
            requestError = error
            group.leave()
        }

        group.notify(queue: .main) {
            if let error = requestError {
                completion(.failure(error))
            } else {
                // Combine both wpcom and email subscribers into a single list
                let followers = Array(
                    followers
                        .sorted(by: { $0.subscribedDate > $1.subscribedDate })
                        .prefix(10)
                )
                completion(.success(followers))
            }
        }
    }
}

extension StatsSubscribersStore {
    enum State<Value: Equatable>: Equatable {
        case idle
        case loading
        case success(Value)
        case error
    }
}
