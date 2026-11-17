@testable import App
import Testing
import VaporTesting

@Suite("Feat-02: Delete a Member")
struct Feat02MemberDeleteTests {
    
    @Test("Successful member delete returns 204 NoContent response")
    func testDeleteMemberReturnsNoContent() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedMember = try await createMemberToManage(app)
            
            try await app.testing().test(.DELETE, "members/\(fetchedMember.requireID())", afterResponse: { res in
                
                #expect(res.status == .noContent)

            })
            
            #expect(try await Member.find(fetchedMember.requireID(), on: app.db) == nil)
        }
    }
    
    @Test("Delete is rejected when member has active loans")
    func testDeleteMemberWithActiveLoansIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedMember = try await createMemberToManage(app)
            
            let game = try await createGameToManage(app)
            
            try await insertLoan(app, gameID: game.requireID(), memberID: fetchedMember.requireID(), borrowedAt: .now, dueAt: .now.addingTimeInterval(14 * 24 * 3600))
            
            try await app.testing().test(.DELETE, "members/\(fetchedMember.requireID())", afterResponse: { res in
                
                #expect(res.status == .conflict)
                
            })
        }
    }
    
    @Test("Delete is rejected when member has finished loans")
    func testDeleteMemberWithPassedLoansIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedMember = try await createMemberToManage(app)
            
            let game = try await createGameToManage(app)
            
            try await insertLoan(app, gameID: game.requireID(), memberID: fetchedMember.requireID(), borrowedAt: .now, dueAt: .now.addingTimeInterval(14 * 24 * 3600), returnedAt: .now)
            
            try await app.testing().test(.DELETE, "members/\(fetchedMember.requireID())", afterResponse: { res in
                
                #expect(res.status == .conflict)
                
            })
        }
    }
    
    @Test("Member to delete doesn't exist in database returns 404 Not Found")
    func testDeleteMemberWithUnknownMemberReturnsNotFound() async throws {
        try await withApp(configure: configure) { app in
            
            try await app.testing().test(.DELETE, "members/\(UUID())", afterResponse: { res in
                
                #expect(res.status == .notFound)
                
            })
            
        }
    }
    
}

