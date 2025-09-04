
//
//  TTSManager.swift
//  MD TalkMan
//
//  Created by ganglinwu on 8/14/25.
//

import Foundation
import AVFoundation

struct CircularBuffer<T> {
    private var buffer: [T?]
    private var head: Int = 0
    private var count: Int = 0
    private let capacity: Int
    
    init(capacity: Int = 10) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    mutating func append(_ element: T) {
        buffer[head] = element
        head = (head + 1) % capacity
        
        if count < capacity {
            count += 1
        }
    }
    
    // Reconstruct chronological order from wrapped physical storage
    var elements: [T] {
        var result: [T] = []
        let startIndex = count == capacity ? head : 0
        
        for i in 0..<count {
            let index = (startIndex + i) % capacity
            if let element = buffer[index] {
                result.append(element)
            }
        }
        return result
    }
    
    func reversed() -> [T] {
        return elements.reversed()
    }
    
    var isEmpty: Bool {
        return count == 0
    }
    
    var isFull: Bool {
        return count == capacity
    }
    
    // Public getter for count
    var size: Int {
        return count
    }
}

enum QueuePriority: Int {
    case background = 0
    case normal = 1
    case interjection = 2
    case urgent = 3
    case critical = 4
}

struct UtteranceMetadata {
    let contentType: ContentSectionType?
    let language: String?
    let isSkippable: Bool
    let interjectionEvents: [InterjectionEvent]
    
    init(contentType: ContentSectionType? = nil, 
         language: String? = nil, 
         isSkippable: Bool = false, 
         interjectionEvents: [InterjectionEvent] = []) {
        self.contentType = contentType
        self.language = language
        self.isSkippable = isSkippable
        self.interjectionEvents = interjectionEvents
    }
}

struct UtterancePerformance {
    let actualDuration: TimeInterval
    let charactersPerSecond: Double
    let completedAt: Date
    
    init(actualDuration: TimeInterval, charactersPerSecond: Double, completedAt: Date = Date()) {
        self.actualDuration = actualDuration
        self.charactersPerSecond = charactersPerSecond
        self.completedAt = completedAt
    }
}

struct QueuedUtterance {
    let utterance: AVSpeechUtterance
    let startPosition: Int
    let endPosition: Int
    let sectionIndex: Int
    let isInterjection: Bool
    let priority: QueuePriority
    let metadata: UtteranceMetadata?
    let performance: UtterancePerformance?
    }

class UtteranceQueueManager: ObservableObject {
    private var utteranceQueue: [QueuedUtterance] = []
    // private var tempQueue: [QueuedUtterance] = []  // TODO: Not currently used - may implement for complex interjection scenarios
    private var recycleQueue: CircularBuffer<QueuedUtterance>
    
    // Configuration
    private let maxRecycleQueueSize = 10
    private let contextReplayDepth = 3
    
    init() {
        recycleQueue = CircularBuffer<QueuedUtterance>(capacity: maxRecycleQueueSize)
    }

    // Move completed utterance to recycle queue for instant replay
    func moveToRecycleQueue(_ completedUtterance: QueuedUtterance, performance: UtterancePerformance) {
        let utteranceWithPerformance = QueuedUtterance(
            utterance: completedUtterance.utterance,
            startPosition: completedUtterance.startPosition,
            endPosition: completedUtterance.endPosition,
            sectionIndex: completedUtterance.sectionIndex,
            isInterjection: completedUtterance.isInterjection,
            priority: completedUtterance.priority,
            metadata: completedUtterance.metadata,
            performance: performance
        )
        
        recycleQueue.append(utteranceWithPerformance)
        print("♻️ Moved to recycle queue: \(completedUtterance.startPosition)-\(completedUtterance.endPosition)")
    }
    
    // Pop first utterance from queue and prepare for speaking
    func fetchNextFromUtteranceQueue() -> QueuedUtterance? {
        guard !utteranceQueue.isEmpty else { return nil }
        
        let nextUtterance = utteranceQueue.removeFirst()
        print("🎵 Fetched next utterance: \(nextUtterance.startPosition)-\(nextUtterance.endPosition)")
        
        return nextUtterance
    }

    // Insert interjection at front of utterance queue with priority
    func insertAtFrontOfQueue(_ interjectionUtterance: QueuedUtterance) {
        utteranceQueue.insert(interjectionUtterance, at: 0)
        print("⚡ Inserted interjection at front: priority \(interjectionUtterance.priority.rawValue)")
    }
    
    // MARK: - RecycleQueue Operations
    
    // Find utterances for instant replay (backward scrubbing)
    func findReplayUtterances(seconds: TimeInterval) -> [QueuedUtterance]? {
        let targetDuration = seconds
        var accumulatedDuration: TimeInterval = 0
        var replayUtterances: [QueuedUtterance] = []
        
        // Work backwards through recycle queue
        for utterance in recycleQueue.reversed() {
            guard let performance = utterance.performance else { continue }
            
            replayUtterances.insert(utterance, at: 0)  // Maintain chronological order
            accumulatedDuration += performance.actualDuration
            
            if accumulatedDuration >= targetDuration {
                break
            }
        }
        
        return replayUtterances.isEmpty ? nil : replayUtterances
    }
    
    // Get last main content utterance (non-interjection) for context replay
    func getLastMainContentUtterance() -> QueuedUtterance? {
        return recycleQueue.reversed().first { !$0.isInterjection }
    }
    
    // Get utterances for context replay (replay from N sections back)
    func getContextReplayUtterances() -> [QueuedUtterance] {
        let mainContentUtterances = recycleQueue.elements.filter { !$0.isInterjection }
        
        guard mainContentUtterances.count >= contextReplayDepth else {
            return Array(mainContentUtterances.suffix(mainContentUtterances.count))
        }
        
        return Array(mainContentUtterances.suffix(contextReplayDepth))
    }
    
    // MARK: - Queue State
    
    var queueCount: Int {
        return utteranceQueue.count
    }
    
    var recycleQueueCount: Int {
        return recycleQueue.size
    }
    
    var hasRecycledContent: Bool {
        return !recycleQueue.isEmpty
    }
    
    // MARK: - Queue Manipulation Methods
    
    /// Add utterance to the back of the main queue
    func appendUtterance(_ queuedUtterance: QueuedUtterance) {
        utteranceQueue.append(queuedUtterance)
        print("📝 Appended utterance to queue: \(queuedUtterance.startPosition)-\(queuedUtterance.endPosition)")
    }
    
    /// Add multiple utterances to the back of the main queue
    func appendUtterances(_ queuedUtterances: [QueuedUtterance]) {
        utteranceQueue.append(contentsOf: queuedUtterances)
        print("📝 Appended \(queuedUtterances.count) utterances to queue")
    }
    
    /// Clear the main utterance queue only (preserves recycle queue for instant replay)
    func clearMainQueue() {
        utteranceQueue.removeAll()
        print("🗑️ Cleared main utterance queue")
    }
    
    /// Reset everything including recycle queue (nuclear option for complete restart)
    func resetAllQueues() {
        utteranceQueue.removeAll()
        recycleQueue = CircularBuffer<QueuedUtterance>(capacity: maxRecycleQueueSize)
        print("🗑️ Reset all queues including recycle queue")
    }
    
    /// Check if the main utterance queue is empty
    var isMainQueueEmpty: Bool {
        return utteranceQueue.isEmpty
    }
    
    /// Get the last utterance in the main queue (for lazy loading next content)
    func getLastUtterance() -> QueuedUtterance? {
        return utteranceQueue.last
    }
    
    /// Get the first utterance in the main queue (for debugging/inspection)
    func getFirstUtterance() -> QueuedUtterance? {
        return utteranceQueue.first
    }
}
