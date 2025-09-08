#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Foundation
import UIKit
import Combine

/**
Helper class to produce device information context for the Confidence context.

The values appended to the Context come primarily from the Bundle or UiDevice API

AppInfo contains:
- version: the version name of the app.
- build: the version code of the app.
- namespace: the package name of the app.

DeviceInfo contains:
- manufacturer: the manufacturer of the device.
- brand: the brand of the device.
- model: the model of the device.
- type: the type of the device.

OsInfo contains:
- name: the name of the OS.
- version: the version of the OS.

Locale contains:
- locale: the locale of the device.
- preferred_languages: the preferred languages of the device.

The context is only updated when the class is initialized and then static.
*/
public class ConfidenceDeviceInfoContextDecorator {
    private let staticContext: ConfidenceValue

    public init(
        withDeviceInfo: Bool = false,
        withAppInfo: Bool = false,
        withOsInfo: Bool = false,
        withLocale: Bool = false
    ) {
        var context: [String: ConfidenceValue] = [:]

        if withDeviceInfo {
            let device = UIDevice.current

            context["device"] = .init(structure: [
                "manufacturer": .init(string: "Apple"),
                "model": .init(string: Self.getDeviceModelIdentifier()),
                "type": .init(string: device.model)
            ])
        }

        if withAppInfo {
            let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            let bundleId = Bundle.main.bundleIdentifier ?? ""

            context["app"] = .init(structure: [
                "version": .init(string: currentVersion),
                "build": .init(string: currentBuild),
                "namespace": .init(string: bundleId)
            ])
        }

        if withOsInfo {
            let device = UIDevice.current

            context["os"] = .init(structure: [
                "name": .init(string: device.systemName),
                "version": .init(string: device.systemVersion)
            ])
        }

        if withLocale {
            let locale = Locale.current
            let preferredLanguages = Locale.preferredLanguages

            // Top level fields
            context["locale"] = .init(string: locale.identifier) // Locale identifier (e.g., "en_US")
            context["preferred_languages"] = .init(list: preferredLanguages.map { lang in
                .init(string: lang)
            })
        }

        self.staticContext = .init(structure: context)
    }

    /**
    Returns a context where values are decorated (appended) according to how the
    ConfidenceDeviceInfoContextDecorator was setup.
    The context values in the parameter context have precedence over the fields appended by this class.
    */
    public func decorated(context contextToDecorate: [String: ConfidenceValue]) -> [String: ConfidenceValue] {
        var result = self.staticContext.asStructure() ?? [:]
        contextToDecorate.forEach { (key: String, value: ConfidenceValue) in
            result[key] = value
        }
        return result
    }


    private static func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children
            .compactMap { element in element.value as? Int8 }
            .filter { $0 != 0 }
            .map {
                Character(UnicodeScalar(UInt8($0)))
            }
        return String(identifier)
    }
}
#endif
