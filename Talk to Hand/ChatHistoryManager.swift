//
//  ChatHistoryManager.swift
//  Talk to Hand
//
//  Created by derham on 7/15/25.
//

import CoreData

class ChatHistoryManager {
    static let shared = ChatHistoryManager()
    private let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "ChatHistoryCoreDataModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                print("Failed to load Core Data: \(error.localizedDescription)")
            }
        }
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Fetch all messages, sorted oldest to newest
    func fetch() -> [ChatMessage] {
        let request: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        do {
            let results = try viewContext.fetch(request)
            return results.map { $0.toChatMessage() }
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }

    /// Save overwrites all previous history (simple strategy)
    func save(messages: [ChatMessage]) {
        // Delete all previous messages (unless you want incremental add/remove)
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ChatMessageEntity.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try viewContext.execute(batchDelete)
        } catch {
            print("Failed batch delete: \(error)")
        }

        // Add current messages
        for message in messages {
            let entity = ChatMessageEntity(context: viewContext)
            entity.id = message.id
            entity.content = message.text
            entity.isBotMessage = message.isUser
            entity.timestamp = message.timestamp
        }

        do {
            try viewContext.save()
        } catch {
            print("Save error: \(error)")
        }
    }
}
