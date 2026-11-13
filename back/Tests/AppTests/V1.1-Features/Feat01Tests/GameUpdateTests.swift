@testable import App
import Testing
import VaporTesting

@Suite("Feat-01: Update a Game")
struct Feat01GameUpdateTests {
    
    @Test("Successful game update returns 200 OK response")
    func testUpdateGameReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            let input = UpdateGameDTO(title: "Blocus", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            let fetchedGame = try await createGameToManage(app)
            
            try await app.testing().test(.PUT, "games/\(fetchedGame.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let game = try res.content.decode(GameDTO.self)
                
                #expect(game.title == input.title)
                #expect(game.minPlayers == input.minPlayers)
                #expect(game.maxPlayers == input.maxPlayers)
                #expect(game.durationMinutes == input.durationMinutes)
                
            })
        }
    }
    
    @Test("Update is rejected when new game title is empty")
    func testUpdateGameWithEmptyTitleIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let input = UpdateGameDTO(title: "", minPlayers: nil, maxPlayers: nil, durationMinutes: nil)
            let fetchedGame = try await createGameToManage(app)
            
            try await app.testing().test(.PUT, "games/\(fetchedGame.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
        }
    }
    
    @Test("Update is rejected when new game minPlayers is greater than maxPlayers in database")
    func testUpdateGameWithMinPlayersGreaterThanMaxPlayerInExistingGameIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let input = UpdateGameDTO(title: nil, minPlayers: 100, maxPlayers: nil, durationMinutes: nil)
            let fetchedGame = try await createGameToManage(app)
            
            try await app.testing().test(.PUT, "games/\(fetchedGame.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
    @Test("Update is rejected when new game minPlayers is greater than maxPlayers in request")
    func testUpdateGameWithMinPlayersGreaterThanMaxPlayerInNewGameIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let input = UpdateGameDTO(title: nil, minPlayers: 100, maxPlayers: 10, durationMinutes: nil)
            let fetchedGame = try await createGameToManage(app)
            
            try await app.testing().test(.PUT, "games/\(fetchedGame.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
    @Test("Invalid gameID parameters returns 400 Bad Request response")
    func testUpdateGameWithInvalidIDReturnsBadRequest() async throws {
        try await withApp(configure: configure) { app in
            
            let input = UpdateGameDTO(title: "Blocus", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            
            try await app.testing().test(.PUT, "games/not-a-uuid", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
    @Test("Game to update doesn't exist in database returns 404 Not Found")
    func testUpdateGameWithUnknownGameReturnsNotFound() async throws {
        try await withApp(configure: configure) { app in
            
            let input = UpdateGameDTO(title: "Blocus", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            
            try await app.testing().test(.PUT, "games/\(UUID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .notFound)
                
            })
            
        }
    }
    
}
