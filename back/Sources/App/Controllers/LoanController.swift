import Fluent
import Vapor

struct LoanController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let loans = routes.grouped("loans")
        loans.post(use: create)
        loans.post(":loanID", "return", use: returnGame)
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let dto = try req.content.decode(CreateLoanDTO.self)

        guard let game = try await Game.find(dto.gameID, on: req.db) else {
            throw Abort(.notFound, reason: "Game not found")
        }
        guard let member = try await Member.find(dto.memberID, on: req.db) else {
            throw Abort(.notFound, reason: "Member not found")
        }
        
        try await ensureGameIsNotLoaned(for : game, on: req.db)
        
        let now = Date()
        let loan = Loan(
            gameID: try game.requireID(),
            memberID: try member.requireID(),
            borrowedAt: now,
            dueAt: try Loan.dueDate(from: now)
        )
        
        try await loan.save(on: req.db)
        return try await loan.toDTO().encodeResponse(status: .created, for: req)
    }
}

extension LoanController {
    
    //MARK: Feat-03(return a game) methods
    @Sendable
    func returnGame(req: Request) async throws -> Response {
        
        guard let id = req.parameters.get("loanID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid loan id")
        }
        guard let loan = try await Loan.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Loan not found")
        }
        
        guard loan.returnedAt == nil else {
            throw Abort(.conflict, reason: "Loan is already returned")
        }
        
        loan.returnedAt = Date()
        
        try await loan.save(on: req.db)
        return try await loan.toDTO().encodeResponse(status: .ok, for: req)
        
    }
}

extension LoanController {
    
    private func ensureGameIsNotLoaned(for game: Game, on db: any Database) async throws {
        
        let requestedLoan = try await Loan.query(on: db)
            .filter( \.$game.$id == game.requireID())
            .filter(\.$returnedAt == nil)
            .count()
        
        guard requestedLoan <= 0 else {
            throw Abort(.conflict, reason: "Game is already on loan")
        }

    }
    
}
