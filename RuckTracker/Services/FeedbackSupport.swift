
// FeedbackSupport.swift
// Opens the user's email app with pre-filled feedback to hello@artless.app.

import Foundation
import UIKit

struct FeedbackDeviceContext {
    let appVersion: String
    let osVersion: String
    let deviceModel: String

    static func current() -> FeedbackDeviceContext {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return FeedbackDeviceContext(
            appVersion: "\(version) (\(build))",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model
        )
    }
}

enum FeedbackMailer {
    static let supportEmail = "hello@artless.app"

    static func send(
        category: String,
        message: String,
        source: String,
        context: FeedbackDeviceContext = .current()
    ) -> Bool {
        let body = """
        Category: \(category)
        Source: \(source)
        App: \(context.appVersion)
        iOS: \(context.osVersion)
        Device: \(context.deviceModel)

        \(message)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "MARCH Feedback"),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { return false }
        #if targetEnvironment(simulator)
        print("💬 mailto: \(url.absoluteString)")
        return true
        #else
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url)
        return true
        #endif
    }
}
