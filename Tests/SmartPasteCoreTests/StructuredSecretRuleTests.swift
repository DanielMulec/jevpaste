import SmartPasteCore
import Testing

/// The rules whose shape is more than a prefix: PEM private-key blocks, JSON Web Tokens and connection strings
/// with inline credentials. All secrets here are synthetic.
struct StructuredSecretRuleTests {
    static let jwtHeader = "eyJhbGciOiJIUzI1NiJ9"
    static let jwtPayload = "eyJzdWIiOiJqZXZwYXN0ZSJ9"
    static let jwtSignature = "SmV2UGFzdGUtc2lnbmF0dXJl_x-0"

    @Test(arguments: [
        "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg\n-----END PRIVATE KEY-----",
        "key:\n-----BEGIN RSA PRIVATE KEY-----\nMIIEow",
        "-----BEGIN OPENSSH PRIVATE KEY-----",
        "-----BEGIN EC PRIVATE KEY-----",
        "-----BEGIN ENCRYPTED PRIVATE KEY-----",
    ])
    func pemPrivateKeyMatches(text: String) {
        #expect(SuspectedSecretRule.pemPrivateKey.matches(text))
    }

    @Test(arguments: [
        "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZI\n-----END PUBLIC KEY-----",
        "-----BEGIN CERTIFICATE-----",
        "-----BEGIN RSA\nPRIVATE KEY-----",
        "a line mentioning PRIVATE KEY----- without a header",
    ])
    func pemPrivateKeyIgnores(text: String) {
        #expect(!SuspectedSecretRule.pemPrivateKey.matches(text))
    }

    @Test(arguments: [
        "\(jwtHeader).\(jwtPayload).\(jwtSignature)",
        "Authorization: Bearer \(jwtHeader).\(jwtPayload).\(jwtSignature)\n",
    ])
    func jsonWebTokenMatches(text: String) {
        #expect(SuspectedSecretRule.jsonWebToken.matches(text))
    }

    @Test(arguments: [
        "\(jwtHeader).\(jwtPayload)",
        "\(jwtHeader).\(jwtPayload).",
        "\(jwtHeader).notAJsonPayload0000.\(jwtSignature)",
        "x\(jwtHeader).\(jwtPayload).\(jwtSignature)",
        "\(jwtHeader).\(jwtPayload).short",
    ])
    func jsonWebTokenIgnores(text: String) {
        #expect(!SuspectedSecretRule.jsonWebToken.matches(text))
    }

    @Test(arguments: [
        "DATABASE_URL=postgres://jev:hunter2@db.example.org:5432/app",
        "mongodb+srv://probe:s3cr%40t@cluster0.example.net/?retryWrites=true",
        "redis://:swordfish@cache.example.org:6379",
        "see https://admin:letmein@intranet.example.org/wiki",
        // Accepted: `docs.example.org:443` here is syntactically userinfo (user `docs.example.org`, password
        // `443`), so the shape alone cannot tell it from a credential.
        "https://docs.example.org:443@archive.example.org/",
    ])
    func connectionStringCredentialsMatch(text: String) {
        #expect(SuspectedSecretRule.connectionStringCredentials.matches(text))
    }

    @Test(arguments: [
        "https://example.org/users/a@b",
        "postgres://jev@db.example.org/app",
        "postgres://jev:@db.example.org/app",
        "https://example.org:8443/path",
        "mailto:ada@example.org",
        "ftp://host.example.org/a:b@c",
        "https://alice:note@/docs",
        "https://alice:note@",
    ])
    func connectionStringCredentialsIgnore(text: String) {
        #expect(!SuspectedSecretRule.connectionStringCredentials.matches(text))
    }
}
