public class WarrantyUpdateBatch implements Database.Batchable<sObject>, Database.Stateful {
    private Set<Id> warrantyPriorIds;
    private Map<Id, Decimal> warrantyToTotalAmountMap;
    
    public WarrantyUpdateBatch(Set<Id> warrantyIds) {
        this.warrantyPriorIds = warrantyIds;
        this.warrantyToTotalAmountMap = new Map<Id, Decimal>();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Warranty_Prior__c, TotalAmount__c 
            FROM WorkOrderLineItem 
            WHERE Warranty_Prior__c IN :warrantyPriorIds
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<WorkOrderLineItem> scope) {
        for (WorkOrderLineItem woli : scope) {
            if (woli.Warranty_Prior__c == null) continue;
            
            Decimal amount = woli.TotalAmount__c != null ? woli.TotalAmount__c : 0;
            Id warrantyId = woli.Warranty_Prior__c;
            
            if (!warrantyToTotalAmountMap.containsKey(warrantyId)) {
                warrantyToTotalAmountMap.put(warrantyId, 0);
            }
            warrantyToTotalAmountMap.put(warrantyId, warrantyToTotalAmountMap.get(warrantyId) + amount);
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        if (warrantyPriorIds.isEmpty()) return;
        
        // Query ONLY warranties that still exist
        Map<Id, Warranty_Prior__c> existingWarranties = new Map<Id, Warranty_Prior__c>([
            SELECT Id FROM Warranty_Prior__c WHERE Id IN :warrantyPriorIds
        ]);
        
        List<Warranty_Prior__c> warrantiesToUpdate = new List<Warranty_Prior__c>();
        for (Id warrantyId : warrantyPriorIds) {
            // Only process warranties that still exist
            if (!existingWarranties.containsKey(warrantyId)) continue;
            
            // Ensure ID is properly set
            if (warrantyId == null) continue;
            
            warrantiesToUpdate.add(new Warranty_Prior__c(
                Id = warrantyId,
                Total_Claim_Amount__c = warrantyToTotalAmountMap.get(warrantyId) != null 
                                      ? warrantyToTotalAmountMap.get(warrantyId) 
                                      : 0
            ));
        }
        
        if (!warrantiesToUpdate.isEmpty()) {
            update warrantiesToUpdate;
        }
    }
}