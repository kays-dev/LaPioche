@testable import App
import Testing
import VaporTesting

@Suite("Feat-02: Update a Member")
struct Feat02MemberUpdateTests {
    
    @Test("Successful member update returns 200 OK response")
    func testUpdateMemberReturnsOK() async throws {
        try await withApp(configure: configure) { app in
            
            let input = CreateMemberDTO(name: "Krys", email: "krys@lapioche.com")
            let fetchedMember = try await createMemberToManage(app)
            
            try await app.testing().test(.PUT, "members/\(fetchedMember.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .ok)
                
                let member = try res.content.decode(MemberDTO.self)
                
                #expect(member.name == input.name)
                #expect(member.email == input.email)
                
            })
        }
    }
    
    @Test("Update is rejected when new member name is empty")
    func testUpdateMemberWithEmptyNameIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let input = CreateMemberDTO(name: "", email: "krys@lapioche.com")
            let fetchedMember = try await createMemberToManage(app)
            
            try await app.testing().test(.PUT, "members/\(fetchedMember.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
        }
    }
    
    @Test("Update is rejected when new member email is already taken")
    func testUpdateMemberWithTakenEmailIsRejected() async throws {
        try await withApp(configure: configure) { app in
            
            let otherMember = try await createMemberToManage(app, name: "Opale", email: "opale@example.com")
            let input = CreateMemberDTO(name: "Krys", email: otherMember.email)
            let fetchedMember = try await createMemberToManage(app)
            
            try await app.testing().test(.PUT, "members/\(fetchedMember.requireID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .conflict)
                
            })
            
        }
    }
    
    @Test("Invalid memberID parameters returns 400 Bad Request response")
    func testUpdateMemberWithInvalidIDReturnsBadRequest() async throws {
        try await withApp(configure: configure) { app in
            
            let input = CreateMemberDTO(name: "Krys", email: "krys@lapioche.com")

            try await app.testing().test(.PUT, "members/not-a-uuid", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .badRequest)
                
            })
            
        }
    }
    
    @Test("Member to update doesn't exist in database returns 404 Not Found")
    func testUpdateMemberWithUnknownMemberReturnsNotFound() async throws {
        try await withApp(configure: configure) { app in
            
            let input = CreateMemberDTO(name: "Krys", email: "krys@lapioche.com")

            try await app.testing().test(.PUT, "members/\(UUID())", beforeRequest: { req in
                
                try req.content.encode(input)
                
            }, afterResponse: { res in
                
                #expect(res.status == .notFound)
                
            })
            
        }
    }
    
}
