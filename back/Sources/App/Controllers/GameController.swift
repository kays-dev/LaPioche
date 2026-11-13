import Fluent
import Vapor

struct GameController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let games = routes.grouped("games")
        games.get(use: index)
        games.post(use: create)
        games.get(":gameID", use: show)
        games.put(":gameID", use: update)
    }
    
    @Sendable
    func index(req: Request) async throws -> [GameDTO] {
        let games = try await Game.query(on: req.db)
            .with(\.$loans)
            .all()
        return games.map { $0.toDTO() }
    }
    
    @Sendable
    func create(req: Request) async throws -> Response {
        try CreateGameDTO.validate(content: req)
        let dto = try req.content.decode(CreateGameDTO.self)
        try dto.ensureConsistentPlayerCount()
        
        let game = dto.toModel()
        try await game.save(on: req.db)
        return try await game.toDTO().encodeResponse(status: .created,for: req)
    }
    
    @Sendable
    func show(req: Request) async throws -> GameDTO {
        try await findGame(req).toDTO()
    }
    
    private func findGame(_ req: Request) async throws -> Game {
        guard let gameID = req.parameters.get("gameID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid game id")
        }
        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == gameID)
            .with(\.$loans)
            .first()
                else {
            throw Abort(.notFound, reason: "Game not found")
        }
        return game
    }
}

extension GameController {
    
    @Sendable
    func update(req: Request) async throws -> Response {
        
        try UpdateGameDTO.validate(content: req)
        let newGame = try req.content.decode(UpdateGameDTO.self)
        
        let updatedGame = try await applyUpdateData(from: newGame, to: findGame(req))
        
        try await updatedGame.save(on: req.db)
        return try await updatedGame.toDTO().encodeResponse(status: .ok, for: req)
        
    }
    
    private func applyUpdateData(from newGame: UpdateGameDTO, to game: Game) async throws -> Game {
        
        if let newTitle = newGame.title {
            game.title = newTitle
        }
        
        let newMinPlayers = newGame.minPlayers ?? game.minPlayers
        let newMaxPlayers = newGame.maxPlayers ?? game.maxPlayers
        
        guard newMinPlayers <= newMaxPlayers else {
            throw Abort(.badRequest, reason: "minPlayers must not exceed maxPlayers")
        }
        
        game.minPlayers = newMinPlayers
        game.maxPlayers = newMaxPlayers
        
        
        if let newDurationMinutes = newGame.durationMinutes {
            game.durationMinutes = newDurationMinutes
        }
        
        return game
    }
}
