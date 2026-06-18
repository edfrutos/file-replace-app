import Foundation

public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]

    public init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }

        let withoutBuildMetadata = value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let versionParts = withoutBuildMetadata.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let coreComponents = versionParts[0].split(separator: ".", omittingEmptySubsequences: false)

        guard
            (1...3).contains(coreComponents.count),
            coreComponents.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
        else {
            return nil
        }

        let numericComponents = coreComponents.compactMap { Int($0) }
        guard numericComponents.count == coreComponents.count else { return nil }

        major = numericComponents[0]
        minor = numericComponents.count > 1 ? numericComponents[1] : 0
        patch = numericComponents.count > 2 ? numericComponents[2] : 0

        if versionParts.count == 2 {
            let identifiers = versionParts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !identifiers.isEmpty, identifiers.allSatisfy({ !$0.isEmpty }) else { return nil }
            prerelease = identifiers
        } else {
            prerelease = []
        }
    }

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : "\(core)-\(prerelease.joined(separator: "."))"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }

        for (left, right) in zip(lhs.prerelease, rhs.prerelease) {
            if left == right { continue }

            switch (Int(left), Int(right)) {
            case let (.some(leftNumber), .some(rightNumber)):
                return leftNumber < rightNumber
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return left < right
            }
        }

        return lhs.prerelease.count < rhs.prerelease.count
    }
}
