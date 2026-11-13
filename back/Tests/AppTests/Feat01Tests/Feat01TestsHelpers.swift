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

func createMemberToManageGame(
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
