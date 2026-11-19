@testable import App
import Testing
import VaporTesting

@Suite("Feat-06: Search a Game")
struct Feat06GameSearchTests {
    
    @Test("Successful game search with all parameters returns 200 OK response")
    func testSearchGameWithAllParametersReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            try await gameExamples(app)
            
            let q = "dix"
            let players = 3
            let maxDuration = 60
            
            try await app.testing().test(.GET, "games?q=\(q)&players=\(players)&maxDuration=\(maxDuration)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Dixit"))
                
            })
        }
    }
    
    @Test("Successful game search with q parameter returns 200 OK response")
    func testSearchGameWithQParameterReturnsOK() async throws {
        try await withApp(configure: configure) { app in

            try await gameExamples(app)
            
            let q = "cat"
            
            try await app.testing().test(.GET, "games?q=\(q)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Catan"))
                
            })
        }
    }
    
    @Test("Successful game search with players parameter returns 200 OK response")
    func testSearchGameWithPlayersParameterReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            try await gameExamples(app)

            let players = 3
            
            try await app.testing().test(.GET, "games?players=\(players)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Catan"))
                #expect(gameTitles.contains("Dixit"))
                #expect(gameTitles.contains("Uno"))
                
            })
        }
    }
    
    @Test("Successful game search with maxDuration parameter returns 200 OK response")
    func testSearchGameWithMaxDurationParameterReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            try await gameExamples(app)
            
            let maxDuration = 45
            
            try await app.testing().test(.GET, "games?maxDuration=\(maxDuration)",afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Dixit"))
                #expect(gameTitles.contains("Uno"))
                
            })
        }
    }
    
    @Test("Search with no parameter gets game list returns 200 OK response")
    func testSearchGameWithNoParameterReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            try await gameExamples(app)
            
            try await app.testing().test(.GET, "games", afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let gameTitles = try titles(of: res)
                #expect(gameTitles.contains("Catan"))
                #expect(gameTitles.contains("Dixit"))
                #expect(gameTitles.contains("Uno"))
                
            })
        }
    }

    @Test("Invalid parameters returns 400 Bad Request response",arguments: ["players=0", "players=-2", "players=abc", "maxDuration=0", "maxDuration=not-an-int"])
    func testSearchGameWithInvalidIntParameterReturnsBadRequest(params: String) async throws {
        try await withApp(configure: configure) { app in
            
            try await app.testing().test(.GET, "games?\(params)", afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
}
