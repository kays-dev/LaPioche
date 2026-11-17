@testable import App
import Testing
import VaporTesting

@Suite("Feat-03: Return a Loan")
struct Feat03LoanReturnTests {
    
    @Test("Successful loan return returns 200 Ok response")
    func testReturnLoanReturnsOk() async throws {
        try await withApp(configure : configure){ app in
        
            let fetchedLoan = try await borrow(app)
            
            try await app.testing().test(.POST, "loans/\(fetchedLoan.requireID())/return", afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let responseLoan = try res.content.decode(LoanDTO.self)
                #expect(responseLoan.returnedAt != nil)
                
            })
            
        }
    }
    
    @Test("Returned game can be borrowed again")
    func testReturnLoanAndBorrowAgain() async throws {
        try await withApp(configure : configure){ app in
        
            let fetchedLoan = try await borrow(app, returned: true)
            
            try await app.testing().test(.POST, "loans", beforeRequest: { req in
                
                try req.content.encode(CreateLoanDTO(gameID: fetchedLoan.$game.id, memberID: fetchedLoan.$member.id))
                
            }, afterResponse: { res in
                
                #expect(res.status == .created)
                
            })
            
        }
    }
    
    @Test("Return is rejected when loan is already returned")
    func testReturnLoanWithAlreadyReturnedLoanIsRejected() async throws {
        try await withApp(configure : configure){ app in
        
            let fetchedLoan = try await borrow(app, returned: true)
            
            try await app.testing().test(.POST, "loans/\(fetchedLoan.requireID())/return", afterResponse: { res in
                
                #expect(res.status == .conflict)
                
            })
            
        }
    }
    
    @Test("Invalid loanID parameters returns 400 Bad Request response")
    func testReturnLoanWithInvalidIDReturnsBadRequest() async throws {
        try await withApp(configure : configure){ app in
            
            try await app.testing().test(.POST, "loans/not-a-uuid/return", afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
    @Test("Loan to return doesn't exist in database returns 404 Not Found")
    func testReturnLoanWithUnknownLoanReturnsNotFound() async throws {
        try await withApp(configure : configure){ app in
            
            try await app.testing().test(.POST, "loans/\(UUID())/return", afterResponse: { res in
                
                #expect(res.status == .notFound)
                
            })
            
        }
    }
}
