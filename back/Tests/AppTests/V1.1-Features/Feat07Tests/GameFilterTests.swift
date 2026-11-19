@testable import App
import Testing
import VaporTesting

@Suite("Feat-07: Filter an available Game")
struct Feat07GameAvailableTests {

    private func gameExamplesWithLoans(_ app: Application) async throws {
        let jumo = Game(title: "Jumo", minPlayers: 2, maxPlayers: 12, durationMinutes: 20)
        let undercover = Game(title: "Undercover", minPlayers: 4, maxPlayers: 20, durationMinutes: 90)
        let pictionary = Game(title: "Pictionary", minPlayers: 2, maxPlayers: 14, durationMinutes: 60)
        
        let sampleGames = [
            jumo,
            undercover,
            pictionary,
        ]
        
        for game in sampleGames {
            try await game.save(on: app.db)
        }
        
        try await camille.save(on: app.db)
        
        let day: TimeInterval = 24 * 3600
        let returnedLoanDay: TimeInterval = -30
        let returnedAfter: TimeInterval = returnedLoanDay + 5
        try await insertLoan(
            app,
            gameID: jumo.requireID(),
            memberID: camille.requireID(),
            borrowedAt: .now,
            dueAt: .now.addingTimeInterval(14 * day)
        ) //unavailable
        try await insertLoan(
            app,
            gameID: pictionary.requireID(),
            memberID: camille.requireID(),
            borrowedAt: .now.addingTimeInterval(returnedLoanDay * day),
            dueAt: .now.addingTimeInterval((14 + returnedLoanDay) * day),
            returnedAt: .now.addingTimeInterval(returnedAfter * day)
        ) //available
    }

    private func titles(of res: TestingHTTPResponse) throws -> Set<String> {
        Set(try res.content.decode([GameDTO].self).map(\.title))
    }
    
    @Test("Successful filter with available game returns 200 OK response")
    func testFilterGameWithAvailableGameReturnsOK() async throws {
        try await withApp(configure: configure) { app in

            try await gameExamplesWithLoans(app)
            
            let available = true
            
            try await app.testing().test(.GET, "games?available=\(available)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(!gameTitles.contains("Jumo"))
                #expect(gameTitles.contains("Pictionary"))
                #expect(gameTitles.contains("Undercover"))
                
            })
        }
    }
    
    @Test("Successful filter with unavailable game returns 200 OK response")
    func testFilterGameWithUnavailableGameReturnsOK() async throws {
        try await withApp(configure: configure) { app in

            try await gameExamplesWithLoans(app)
            
            let available = false
            
            try await app.testing().test(.GET, "games?available=\(available)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Jumo"))
                #expect(!gameTitles.contains("Pictionary"))
                #expect(!gameTitles.contains("Undercover"))
                
            })
        }
    }
    
    @Test("Successful game filter with all search parameters returns 200 OK response")
    func testFilterGameWithAllParametersReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            try await gameExamplesWithLoans(app)
            
            let available = true
            let q = "na"
            let players = 3
            let maxDuration = 60
            
            try await app.testing().test(.GET, "games?q=\(q)&players=\(players)&maxDuration=\(maxDuration)&available=\(available)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(!gameTitles.contains("Jumo"))
                #expect(gameTitles.contains("Pictionary"))
                #expect(!gameTitles.contains("Undercover"))
                
            })
        }
    }
    
    @Test("Successful game search with players parameter returns 200 OK response")
    func testFilterGameWithQParameterReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            try await gameExamplesWithLoans(app)
            
            let available = false
            let players = 4
            
            try await app.testing().test(.GET, "games?players=\(players)&available=\(available)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Jumo"))
                #expect(!gameTitles.contains("Pictionary"))
                #expect(!gameTitles.contains("Undercover"))
                
            })
        }
    }

    @Test("Invalid availability parameters returns 400 Bad Request response",arguments: ["maybe", "yes", "not-a-bool"])
    func testFilterGameWithInvalidIntParameterReturnsBadRequest(value: String) async throws {
        try await withApp(configure: configure) { app in
            
            try await app.testing().test(.GET, "games?available=\(value)", afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
}
