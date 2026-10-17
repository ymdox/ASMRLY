import Foundation

struct Companion: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tagline: String

    static let luna = Companion(
        id: "luna",
        name: "Luna",
        tagline: "warm and comforting"
    )
}
