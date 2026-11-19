@testable import App
import Testing
import VaporTesting


func createGameToManage(
    _ app: Application,
    title: String = "Catan",
    minPlayers: Int = 3,
    maxPlayers: Int = 4,
    durationMinutes: Int = 90
) async throws -> Game {
    
    let game = Game(
        title: title,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        durationMinutes: durationMinutes
    )
    
    try await game.save(on: app.db)
    return game
}

func createMemberToManage(
    _ app: Application,
    name: String = "Camille",
    email: String = "camille@example.com"
) async throws -> Member {
    
    let member = Member(
        name: name,
        email: email
    )
    
    try await member.save(on: app.db)
    return member
}

func borrow(
    _ app: Application,
    returned: Bool = false,
) async throws -> Loan {
    
    let game = try await createGameToManage(app)
    let member = try await createMemberToManage(app)
    
    let loan = Loan(gameID: try game.requireID(), memberID: try member.requireID(), borrowedAt: .now, dueAt: .now.addingTimeInterval(14 * 24 * 3600))
    
    loan.returnedAt = returned ? .now : nil
    
    try await loan.save(on: app.db)
    return loan
}


func gameExamples(_ app: Application) async throws {
    for game in [
        Game(title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90),
        Game(title: "Dixit", minPlayers: 3, maxPlayers: 6, durationMinutes: 30),
        Game(title: "Uno", minPlayers: 2, maxPlayers: 10, durationMinutes: 20),
    ] {
        try await game.save(on: app.db)
    }
}

func titles(of res: TestingHTTPResponse) throws -> Set<String> {
    Set(try res.content.decode([GameDTO].self).map(\.title))
}
