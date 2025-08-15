#!/usr/bin/env swift

import Foundation

// Test script to verify real markdown file loading
func testRealMarkdownLoading() {
    print("📚 Testing Real Markdown File Loading")
    print("=" * 50)
    
    let learningPointsPath = "/Users/ganglinwu/code/swiftui/markdown/learning_points"
    let fileManager = FileManager.default
    
    print("📁 Checking directory: \(learningPointsPath)")
    
    do {
        let fileURLs = try fileManager.contentsOfDirectory(atPath: learningPointsPath)
        let mdFiles = fileURLs.filter { $0.hasSuffix(".md") }.sorted()
        
        print("✅ Found \(mdFiles.count) markdown files")
        
        for (index, fileName) in mdFiles.prefix(10).enumerated() {
            // Test title conversion
            let title = createReadableTitle(from: fileName)
            
            // Test file reading
            let filePath = "\(learningPointsPath)/\(fileName)"
            let fileSize: String
            
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
               let size = attributes[.size] as? Int64 {
                fileSize = "\(size) bytes"
            } else {
                fileSize = "unknown size"
            }
            
            print("\(index + 1). \(title)")
            print("   File: \(fileName)")
            print("   Size: \(fileSize)")
            
            // Test content preview
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let firstLine = content.components(separatedBy: .newlines).first ?? ""
                print("   Preview: \(firstLine.prefix(50))")
                
                // Count sections
                let lines = content.components(separatedBy: .newlines)
                let headerCount = lines.filter { $0.hasPrefix("#") }.count
                let codeBlockCount = content.components(separatedBy: "```").count / 2
                
                print("   Structure: \(headerCount) headers, \(codeBlockCount) code blocks")
                
            } catch {
                print("   ❌ Error reading content: \(error)")
            }
            
            print("")
        }
        
        print("🎯 Expected TTS Benefits:")
        print("✅ Real Swift learning content instead of placeholders")
        print("✅ Actual code examples for technical TTS testing")
        print("✅ Varied content lengths and complexity")
        print("✅ Technical terms for pronunciation testing")
        print("✅ Real-world markdown structures")
        
    } catch {
        print("❌ Error accessing directory: \(error)")
    }
}

func createReadableTitle(from fileName: String) -> String {
    // Convert "swift-01-camera-implementation.md" to "Camera Implementation"
    let nameWithoutExtension = String(fileName.dropLast(3)) // Remove .md
    
    // Remove swift-XX- prefix if present
    let withoutPrefix = nameWithoutExtension.replacingOccurrences(
        of: #"^swift-\d+-"#,
        with: "",
        options: .regularExpression
    )
    
    // Replace hyphens with spaces and capitalize words
    let readable = withoutPrefix
        .replacingOccurrences(of: "-", with: " ")
        .capitalized
    
    return readable
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

testRealMarkdownLoading()