import Foundation
import SwiftUI
import WordPressShared

final class SubmitFeedbackViewController: UIViewController {
    private var source: String

    init(source: String) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .formSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewController = UIHostingController(rootView: SubmitFeedbackView(presentingViewController: self, source: source))
        viewController.configureDefaultNavigationBarAppearance()

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.isTranslucent = true // Reset to default

        addChild(navigationController)
        view.addSubview(navigationController.view)
        navigationController.view.translatesAutoresizingMaskIntoConstraints = false
        view.pinSubviewToAllEdges(navigationController.view)
        navigationController.didMove(toParent: self)
    }
}

private struct SubmitFeedbackView: View {
    weak var presentingViewController: UIViewController?
    let source: String

    @State private var subject = ""
    @State private var text = ""
    @State private var isSubmitting = false
    @State private var isShowingCancellationConfirmation = false
    @State private var isShowingAttachmentsUploadingAlert = false

    @StateObject private var attachmentsViewModel = ZendeskAttachmentsSectionViewModel()

    @FocusState private var isSubjectFieldFocused: Bool

    private let subjectLimit = 100
    private let textLimit = 500

    var isInputEmpty: Bool {
        text.trim().isEmpty && subject.trim().isEmpty
    }

    var body: some View {
        List {
            form
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Strings.cancel) {
                    if isInputEmpty {
                        dismiss()
                    } else {
                        isShowingCancellationConfirmation = true
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Button(Strings.submit, action: submit)
                        .disabled(isInputEmpty)
                }
            }
        }
        .onAppear {
            WPAnalytics.track(.appReviewsOpenedFeedbackScreen, withProperties: ["source": source])
            ZendeskUtils.createIdentitySilentlyIfNeeded()
            isSubjectFieldFocused = true
        }
        .disabled(isSubmitting)
        .confirmationDialog(Strings.cancellationAlertTitle, isPresented: $isShowingCancellationConfirmation) {
            Button(Strings.cancellationAlertContinueEditing, role: .cancel) {}
            Button(Strings.cancellationAlertDiscardFeedbackButton, role: .destructive) {
                dismiss()
            }
        }
        .alert(Strings.attachmentsStillUploadingAlertTitle, isPresented: $isShowingAttachmentsUploadingAlert) {
            Button(Strings.ok) {}
        }
        .onChange(of: isInputEmpty) {
            presentingViewController?.isModalInPresentation = !$0
        }
        .onChange(of: subject) { subject in
            self.subject = String(subject.prefix(subjectLimit))
        }
        .onChange(of: text) { text in
            if text.count > textLimit {
                self.text = String(text.prefix(textLimit))
            }
        }
        .navigationTitle(Strings.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var form: some View {
        Section {
            SupportIdentityView(name: ZendeskUtils.identity.0, email: ZendeskUtils.identity.1)
            TextField(Strings.subject, text: $subject)
                .focused($isSubjectFieldFocused)
        }
        Section {
            TextEditor(text: $text)
                .frame(height: 170)
                .accessibilityLabel(Strings.details)
                .overlay(alignment: .bottomTrailing) {
                    Text(max(0, textLimit - text.count).description)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(text.count >= textLimit ? .red : .secondary)
                        .background(Color(uiColor: .systemBackground))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        if #available(iOS 16, *) {
            ZendeskAttachmentsSection(viewModel: attachmentsViewModel)
                .listRowSeparator(.hidden)
        }
    }

    private func submit() {
        guard attachmentsViewModel.attachments.allSatisfy(\.isUploaded) else {
            isShowingAttachmentsUploadingAlert = true
            return
        }

        wpAssert(!isInputEmpty)

        guard let presentingViewController else {
            return wpAssertionFailure("presentingViewController missing")
        }

        isSubmitting = true

        ZendeskUtils.sharedInstance.createNewRequest(
            in: presentingViewController,
            subject: subject.trim().nonEmptyString(),
            description: text.trim(),
            tags: ["appreview_jetpack", "in_app_feedback"],
            attachments: attachmentsViewModel.attachments.compactMap(\.response),
            alertOptions: nil
        ) { result in
            DispatchQueue.main.async {
                didSubmitFeedback(with: result.map { _ in () })
            }
        }
    }

    private func didSubmitFeedback(with result: Result<Void, ZendeskRequestError>) {
        switch result {
        case .success:
            WPAnalytics.track(.appReviewsSentFeedback, withProperties: ["feedback": text, "source": source])

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let notice = Notice(title: Strings.successNoticeTitle, message: Strings.successNoticeMessage)
            ActionDispatcherFacade().dispatch(NoticeAction.post(notice))

            dismiss()
        case .failure(let error):
            DDLogError("Submitting feedback failed: \(error)")

            UINotificationFeedbackGenerator().notificationOccurred(.error)
            WPError.showAlert(withTitle: Strings.failureAlertTitle, message: error.localizedDescription)
            isSubmitting = false
        }
    }

    private func dismiss() {
        presentingViewController?.presentingViewController?.dismiss(animated: true)
    }

    private var identity: (String?, String?) {
        ZendeskUtils.identity
    }
}

private enum Strings {
    static let ok = NSLocalizedString("submit.feedback.buttonOK", value: "OK", comment: "The button title for the Cancel button in the In-App Feedback screen")
    static let cancel = NSLocalizedString("submit.feedback.buttonCancel", value: "Cancel", comment: "The button title for the Cancel button in the In-App Feedback screen")
    static let submit = NSLocalizedString("submit.feedback.submit.button", value: "Submit", comment: "The button title for the Submit button in the In-App Feedback screen")
    static let title = NSLocalizedString("submit.feedback.title", value: "Feedback", comment: "The title for the the In-App Feedback screen")
    static let subject = NSLocalizedString("submit.feedback.subjectPlaceholder", value: "Subject", comment: "The section title and or placeholder")
    static let details = NSLocalizedString("submit.feedback.subjectPlaceholder", value: "Details", comment: "The section title and or placeholder")

    static let cancellationAlertTitle = NSLocalizedString("submitFeedback.cancellationAlertTitle", value: "Are you sure you want to discard the feedback", comment: "Submit feedback screen cancellation confirmation alert title")
    static let cancellationAlertContinueEditing = NSLocalizedString("submitFeedback.cancellationAlertContinueEditing", value: "Continue Editing", comment: "Submit feedback screen cancellation confirmation alert action")
    static let cancellationAlertDiscardFeedbackButton = NSLocalizedString("submitFeedback.cancellationAlertDiscardFeedbackButton", value: "Discard Feedback", comment: "Submit feedback screen cancellation confirmation alert action")
    static let attachmentsStillUploadingAlertTitle = NSLocalizedString("submitFeedback.attachmentsStillUploadingAlertTitle", value: "Some attachments were not uploaded", comment: "Submit feedback screen failure alert title")
    static let failureAlertTitle = NSLocalizedString("submitFeedback.failureAlertTitle", value: "Failed to submit feedback", comment: "Submit feedback screen failure alert title")
    static let successNoticeTitle = NSLocalizedString("submitFeedback.successNoticeTitle", value: "Feedback sent", comment: "Submit feedback screen submit fsuccess notice title")
    static let successNoticeMessage = NSLocalizedString("submitFeedback.successNoticeMessage", value: "Thank you for helping us improve the app", comment: "Submit feedback screen submit success notice messages")
}

#Preview {
    NavigationView {
        SubmitFeedbackView(source: "preview")
    }
}
