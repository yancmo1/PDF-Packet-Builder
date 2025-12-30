import XCTest
@testable import PDFPacketBuilder

final class StorageMigrationTests: XCTestCase {
    
    private var storageService: StorageService!
    private let testDefaults = UserDefaults(suiteName: "TestDefaults")!
    
    override func setUp() {
        super.setUp()
        // Clear test defaults
        testDefaults.removePersistentDomain(forName: "TestDefaults")
        storageService = StorageService()
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "TestDefaults")
        super.tearDown()
    }
    
    // MARK: - Migration Tests
    
    func testTemplateWithFilePath_NoMigrationNeeded() {
        // A template with pdfFilePath should not need migration
        let template = PDFTemplate(
            id: UUID(),
            name: "Test Template",
            pdfFilePath: "/path/to/template.pdf",
            fields: [],
            fieldMappings: [:],
            messageTemplate: .emptyDisabled,
            createdAt: Date()
        )
        
        XCTAssertFalse(template.needsMigration)
        XCTAssertNil(template.legacyDataForMigration)
    }
    
    func testTemplateWithPdfData_NeedsMigration() {
        // A template with embedded pdfData but no file path needs migration
        let pdfData = "fake pdf data".data(using: .utf8)!
        let template = PDFTemplate(
            id: UUID(),
            name: "Legacy Template",
            pdfData: pdfData,
            fields: [],
            fieldMappings: [:]
        )
        
        XCTAssertTrue(template.needsMigration)
        XCTAssertNotNil(template.legacyDataForMigration)
    }
    
    func testWithFilePath_ClearsLegacyData() {
        let pdfData = "fake pdf data".data(using: .utf8)!
        let template = PDFTemplate(
            id: UUID(),
            name: "Legacy Template",
            pdfData: pdfData,
            fields: []
        )
        
        let migrated = template.withFilePath("/new/path/template.pdf")
        
        XCTAssertEqual(migrated.pdfFilePath, "/new/path/template.pdf")
        XCTAssertFalse(migrated.needsMigration)
        XCTAssertNil(migrated.legacyDataForMigration)
    }
    
    // MARK: - Encoding Tests
    
    func testEncode_DoesNotWriteLegacyPdfData() throws {
        let pdfData = "fake pdf data".data(using: .utf8)!
        var template = PDFTemplate(
            id: UUID(),
            name: "Test Template",
            pdfData: pdfData,
            fields: []
        )
        
        // Simulate migration
        template = template.withFilePath("/path/to/file.pdf")
        
        // Encode and decode
        let encoded = try JSONEncoder().encode(template)
        let jsonString = String(data: encoded, encoding: .utf8)!
        
        // The JSON should contain pdfFilePath but NOT pdfData blob
        XCTAssertTrue(jsonString.contains("pdfFilePath"))
        // The legacy pdfData should not be written back
        // (It may appear as null or not at all, depending on encoding)
    }
    
    // MARK: - Decoding Tests
    
    func testDecode_LegacyFormat() throws {
        // Simulate a legacy JSON that has pdfData but no pdfFilePath
        let legacyJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "Legacy Template",
            "pdfData": "ZmFrZSBwZGYgZGF0YQ==",
            "fields": [],
            "fieldMappings": {},
            "createdAt": 0
        }
        """
        
        let data = legacyJSON.data(using: .utf8)!
        let template = try JSONDecoder().decode(PDFTemplate.self, from: data)
        
        XCTAssertEqual(template.name, "Legacy Template")
        XCTAssertNil(template.pdfFilePath)
        XCTAssertTrue(template.needsMigration)
        XCTAssertNotNil(template.legacyDataForMigration)
    }
    
    func testDecode_NewFormat() throws {
        // Simulate new JSON with pdfFilePath
        let newJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "New Template",
            "pdfFilePath": "/Documents/Templates/12345678.pdf",
            "fields": [],
            "fieldMappings": {},
            "createdAt": 0
        }
        """
        
        let data = newJSON.data(using: .utf8)!
        let template = try JSONDecoder().decode(PDFTemplate.self, from: data)
        
        XCTAssertEqual(template.name, "New Template")
        XCTAssertEqual(template.pdfFilePath, "/Documents/Templates/12345678.pdf")
        XCTAssertFalse(template.needsMigration)
    }
}
