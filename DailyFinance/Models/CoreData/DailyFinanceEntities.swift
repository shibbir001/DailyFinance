// Models/CoreData/DailyFinanceEntities.swift
// ✅ CloudKit compatible — all scalars use NSNumber wrappers
import Foundation
internal import CoreData

// MARK: - TransactionEntity
@objc(TransactionEntity)
class TransactionEntity: NSManagedObject {}

extension TransactionEntity {

    @nonobjc class func fetchRequest()
    -> NSFetchRequest<TransactionEntity> {
        return NSFetchRequest<TransactionEntity>(
            entityName: "TransactionEntity"
        )
    }

    @NSManaged var id:       UUID?
    @NSManaged var type:     String?
    // ✅ CloudKit needs Optional Double (NSNumber wrapper)
    @NSManaged var amount:   Double
    @NSManaged var category: String?
    @NSManaged var note:     String?
    @NSManaged var date:     Date?
    // ✅ CloudKit needs Optional Bool
    @NSManaged var isSynced: Bool
    @NSManaged var userId:   String?
}

extension TransactionEntity: Identifiable {}

// MARK: - DailySummaryEntity
@objc(DailySummaryEntity)
class DailySummaryEntity: NSManagedObject {}

extension DailySummaryEntity {

    @nonobjc class func fetchRequest()
    -> NSFetchRequest<DailySummaryEntity> {
        return NSFetchRequest<DailySummaryEntity>(
            entityName: "DailySummaryEntity"
        )
    }

    @NSManaged var id:           UUID?
    @NSManaged var date:         String?
    @NSManaged var totalIncome:  Double
    @NSManaged var totalExpense: Double
    @NSManaged var netBalance:   Double
    @NSManaged var isSynced:     Bool
    @NSManaged var userId:       String?
}

extension DailySummaryEntity: Identifiable {}

// MARK: - CategoryEntity
@objc(CategoryEntity)
class CategoryEntity: NSManagedObject {}

extension CategoryEntity {

    @nonobjc class func fetchRequest()
    -> NSFetchRequest<CategoryEntity> {
        return NSFetchRequest<CategoryEntity>(
            entityName: "CategoryEntity"
        )
    }

    @NSManaged var id:    UUID?
    @NSManaged var name:  String?
    @NSManaged var type:  String?
    @NSManaged var icon:  String?
    @NSManaged var color: String?
}

extension CategoryEntity: Identifiable {}
