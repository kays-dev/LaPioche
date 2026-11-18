@testable import App
import Testing
import VaporTesting

@Suite("Feat-05: List all overdue loans")
struct Feat05LoanOverdueTests {
    
    @Test("Successful listing of overdue loans returns 200 Ok response")
    func testOverdueLoanReturnsOk() async throws {
        try await withApp(configure : configure){ app in
        
            let fetchedMember = try await createMemberToManage(app)
    
            let game = try await createGameToManage(app)
            
            let day: TimeInterval = 24 * 3600
            let firstLoanDay: TimeInterval = -30
            let returnedAfter: TimeInterval = firstLoanDay + 5
            let secondLoanDay: TimeInterval = -15
            
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
                borrowedAt: .now.addingTimeInterval(secondLoanDay * day),
                dueAt: .now.addingTimeInterval((14 + secondLoanDay) * day)
            )
            
            
            try await app.testing().test(.GET, "loans/overdue", afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let responseLoans = try res.content.decode([LoanDTO].self)
                #expect(responseLoans.count == 1)
                #expect(responseLoans[0].returnedAt == nil)
                #expect(responseLoans[0].dueAt < .now)
                
            })
            
        }
    }
    
}
