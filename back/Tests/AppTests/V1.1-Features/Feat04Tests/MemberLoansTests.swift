@testable import App
import Testing
import VaporTesting

@Suite("Feat-04: Member loans")
struct Feat04MemberLoansTests {
    
    @Test("Successful list of member loans returns 200 OK response")
    func testListMemberLoansReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedMember = try await createMemberToManage(app)
    
            let game = try await createGameToManage(app)
            
            let day: TimeInterval = 24 * 3600
            let firstLoanDay: TimeInterval = -30
            let returnedAfter: TimeInterval = firstLoanDay + 5
            try await insertLoan(
                app,
                gameID: game.requireID(),
                memberID: fetchedMember.requireID(),
                borrowedAt: .now.addingTimeInterval(firstLoanDay * day),
                dueAt: .now.addingTimeInterval((14 + firstLoanDay) * day),
                returnedAt: .now.addingTimeInterval(returnedAfter * day)
            )
            try await insertLoan(
                app,
                gameID: game.requireID(),
                memberID: fetchedMember.requireID(),
                borrowedAt: .now,
                dueAt: .now.addingTimeInterval(14 * day)
            )
            
            try await app.testing().test(.GET, "members/\(fetchedMember.requireID())/loans", afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let loans = try res.content.decode([LoanDTO].self)
                #expect(loans.count == 2)
                #expect(loans[0].returnedAt != nil)
                #expect(loans[1].returnedAt == nil)
                
            })
            
        }
    }
    
    @Test("Successful empty list of member loans returns 200 OK response")
    func testListMemberLoansWithEmptyListReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            
            let fetchedMember = try await createMemberToManage(app)
            
            try await app.testing().test(.GET, "members/\(fetchedMember.requireID())/loans", afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let loans = try res.content.decode([LoanDTO].self)
                #expect(loans.isEmpty == true)
                
            })
            
        }
    }
    
    @Test("Member doesn't exist in database returns 404 Not Found")
    func testListMemberLoansWithUnknownMemberReturnsNotFound() async throws {
        try await withApp(configure: configure) { app in

            try await app.testing().test(.GET, "members/\(UUID())/loans", afterResponse: { res in
                
                #expect(res.status == .notFound)
                
            })
            
        }
    }
}
