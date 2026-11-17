import Fluent
import Vapor

struct MemberController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let members = routes.grouped("members")
        members.get(use: index)
        members.post(use: create)
        members.get(":memberID", use: show)
        members.put(":memberID", use: update)
    }

    @Sendable
    func index(req: Request) async throws -> [MemberDTO] {
        try await Member.query(on: req.db).all().map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try CreateMemberDTO.validate(content: req)
        let dto = try req.content.decode(CreateMemberDTO.self)

        try await checkIfEmailTaken(for: dto, on: req.db)

        let member = dto.toModel()
        try await member.save(on: req.db)
        return try await member.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> MemberDTO {
        return try await findMember(req).toDTO()
    }
}

extension MemberController {
    
    //MARK: Feat-02(update and delete a member) methods
    @Sendable
    func update(req: Request) async throws -> Response {
        
        try CreateMemberDTO.validate(content: req)
        let newMember = try req.content.decode(CreateMemberDTO.self)
        
        let member = try await findMember(req)
        
        try await checkIfEmailTaken(for: newMember,with: member.requireID(),on: req.db)
        
        let updatedMember = applyUpdateData(from: newMember, to: member)
        
        try await updatedMember.save(on: req.db)
        return try await updatedMember.toDTO().encodeResponse(status: .ok, for: req)
    
    }
}

extension MemberController {
    
    //MARK: Feat-02(update and delete a member) helpers
    private func findMember(_ req: Request) async throws -> Member {
        
        guard let memberID = req.parameters.get("memberID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member id")
        }
        
        guard let member = try await Member.query(on: req.db)
            .filter(\.$id == memberID)
            .with(\.$loans)
            .first()
        else {
            throw Abort(.notFound, reason: "Member not found")
        }
        
        return member
        
    }
    
    private func checkIfEmailTaken(for member : CreateMemberDTO,with memberID: UUID? = nil ,on db: any Database) async throws {
        
        var query = Member.query(on: db)
        
        if let memberID {
            
            query = Member.query(on: db)
                .filter(\.$id != memberID)
            
        }
        
        let emailTaken = try await query
            .filter(\.$email == member.email)
            .count() > 0
        guard !emailTaken else {
            throw Abort(.conflict, reason: "A member with this email already exists")
        }

    }
    
    private func applyUpdateData(from newMember: CreateMemberDTO, to member: Member) -> Member {
        
        member.name = newMember.name
        member.email = newMember.email
        
        return member
    }
}
