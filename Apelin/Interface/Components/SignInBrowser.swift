import AuthenticationServices
import UIKit

/// A sign-in page in the system's sign-in browser, which shares Safari's
/// cookies (not `SFSafariViewController`, which does not), so an account
/// already signed in there stays signed in. The sign-in ends elsewhere — a
/// device code approved, a loopback reached — so the session waits on a
/// scheme nothing redirects to and is closed from here when it ends. The
/// user closing it first, or declining the system's prompt, is told to
/// `onClosedByUser`; the sign-in goes on waiting. With no in-app browser to
/// be had the page opens in Safari.
final class SignInBrowser: NSObject {
    var onClosedByUser: (() -> Void)?
    private weak var anchor: UIView?
    private var session: ASWebAuthenticationSession?

    /// Presents over `anchor`'s window.
    init(anchor: UIView) {
        self.anchor = anchor
    }

    func open(_ page: URL) {
        close()
        var session: ASWebAuthenticationSession?
        session = ASWebAuthenticationSession(url: page, callbackURLScheme: "apelin-sign-in") { [weak self] _, _ in
            // closed here on purpose, the session is already let go
            guard let self, let current = session, self.session === current else { return }
            self.session = nil
            onClosedByUser?()
        }
        guard let session else { return }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        if !session.start() {
            self.session = nil
            UIApplication.shared.open(page)
        }
    }

    /// Opens a page in Reynard when installed, then falls back to the
    /// system sign-in browser if the app is not available.
    func openInReynard(_ page: URL) {
        var components = URLComponents(string: "reynard://open")
        components?.queryItems = [URLQueryItem(name: "url", value: page.absoluteString)]
        guard let url = components?.url else {
            open(page)
            return
        }
        UIApplication.shared.open(url) { [weak self] opened in
            guard !opened else { return }
            DispatchQueue.main.async { self?.open(page) }
        }
    }

    /// Let go first, then cancel: the session's own completion then knows
    /// it was closed from here.
    func close() {
        let session = session
        self.session = nil
        session?.cancel()
    }
}

extension SignInBrowser: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor?.window ?? ASPresentationAnchor()
    }
}
