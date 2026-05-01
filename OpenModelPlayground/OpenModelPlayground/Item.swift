import Foundation

struct Item: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
