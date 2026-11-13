import Vapor

struct UpdateGameDTO: Content, Validatable {
    let title: String?
    let minPlayers: Int?
    let maxPlayers: Int?
    let durationMinutes: Int?

    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty, required: false)
        validations.add("minPlayers", as: Int.self, is: .range(1...), required: false)
        validations.add("maxPlayers", as: Int.self, is: .range(1...), required: false)
        validations.add("durationMinutes", as: Int.self, is: .range(1...), required: false)
    }

}
