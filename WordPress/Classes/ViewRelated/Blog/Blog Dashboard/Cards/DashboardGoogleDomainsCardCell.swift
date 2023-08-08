import UIKit
import SwiftUI

final class DashboardGoogleDomainsCardCell: DashboardCollectionViewCell {
    private let frameView = BlogDashboardCardFrameView()
    private weak var presentingViewController: UIViewController?
    private var didConfigureHostingController = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFrameView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(blog: Blog, viewController: BlogDashboardViewController?, apiResponse: BlogDashboardRemoteEntity?) {
        self.presentingViewController = viewController

        if let presentingViewController, !didConfigureHostingController {
            let hostingController = UIHostingController(rootView: DashboardGoogleDomainsCardView(buttonClosure: { [weak self] in
                self?.presentGoogleDomainsWebView()
            }))

            guard let cardView = hostingController.view else {
                return
            }

            frameView.add(subview: cardView)

            presentingViewController.addChild(hostingController)

            cardView.backgroundColor = .clear
            frameView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(frameView)
            contentView.pinSubviewToAllEdges(frameView, priority: .defaultHigh)
            hostingController.didMove(toParent: presentingViewController)
            configureMoreButton(with: blog)

            didConfigureHostingController = true
        }
    }

    private func setupFrameView() {
        frameView.setTitle(Strings.cardTitle)
        frameView.onEllipsisButtonTap = {
            WPAnalytics.track(.domainTransferMoreTapped)
        }
        frameView.ellipsisButton.showsMenuAsPrimaryAction = true
        frameView.onViewTap = { [weak self] in
            guard let self else {
                return
            }

            self.presentGoogleDomainsWebView()
        }
    }

    private func configureMoreButton(with blog: Blog) {
        frameView.addMoreMenu(
            items:
                [UIMenu(options: .displayInline, children: [BlogDashboardHelpers.makeHideCardAction(for: .googleDomains, blog: blog)])],
            card: .googleDomains
        )
    }

    private func presentGoogleDomainsWebView() {
        guard let url = URL(string: Constants.transferDomainsURL) else {
            return
        }

        let webViewController = WebViewControllerFactory.controllerAuthenticatedWithDefaultAccount(
            url: url,
            source: "domain_focus_card"
        )
        let navController = UINavigationController(rootViewController: webViewController)
        presentingViewController?.present(navController, animated: true)

        WPAnalytics.track(.domainTransferButtonTapped)
    }
}

private extension DashboardGoogleDomainsCardCell {
    enum Strings {
        static let cardTitle = NSLocalizedString(
            "mySite.domain.focus.card.title",
            value: "News",
            comment: "Title for the domain focus card on My Site"
        )
    }

    enum Constants {
        static let transferDomainsURL = "https://wordpress.com/transfer-google-domains/"
    }
}
