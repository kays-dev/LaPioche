@testable import App
import Testing
import VaporTesting

@Suite("Feat-01: Delete a Game")
struct Feat01GameDeleteTests {
    
    @Test("Successful game delete returns 204 NoContent response")
    func testDeleteGameReturnsNoContent() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedGame = try await createGameToManage(app)
            
            try await app.testing().test(.DELETE, "games/\(fetchedGame.requireID())", afterResponse: { res in
                
                #expect(res.status == .noContent)

            })
            
            #expect(try await Game.find(fetchedGame.requireID(), on: app.db) == nil)
        }
    }
    
    @Test("Delete is rejected when game has active loans")
    func testDeleteGameWithActiveLoansIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedGame = try await createGameToManage(app)
            
            let member = try await createMemberToManageGame(app)
            
            try await insertLoan(app, gameID: fetchedGame.requireID(), memberID: member.requireID(), borrowedAt: .now, dueAt: .now.addingTimeInterval(14 * 24 * 3600))
            
            try await app.testing().test(.DELETE, "games/\(fetchedGame.requireID())", afterResponse: { res in
                
                #expect(res.status == .conflict)
                
            })
        }
    }
    
    @Test("Delete is rejected when game has finished loans")
    func testDeleteGameWithPassedLoansIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedGame = try await createGameToManage(app)
            
            let member = try await createMemberToManageGame(app)
            
            try await insertLoan(app, gameID: fetchedGame.requireID(), memberID: member.requireID(), borrowedAt: .now, dueAt: .now.addingTimeInterval(14 * 24 * 3600), returnedAt: .now)
            
            try await app.testing().test(.DELETE, "games/\(fetchedGame.requireID())", afterResponse: { res in
                
                #expect(res.status == .conflict)
                
            })
        }
    }
    
    @Test("Game to delete doesn't exist in database returns 404 Not Found")
    func testDeleteGameWithUnknownGameReturnsNotFound() async throws {
        try await withApp(configure: configure) { app in
            
            try await app.testing().test(.DELETE, "games/\(UUID())", afterResponse: { res in
                
                #expect(res.status == .notFound)
                
            })
            
        }
    }
    
}
