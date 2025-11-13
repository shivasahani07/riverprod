trigger WarrantyPriorTrigger on Warranty_Prior__c (before update,after update, before delete) {
    if (Trigger.isAfter && Trigger.isUpdate) {
       // WarrantyPriorTriggerHandler.creatClaimLineItemPartJobsAdded(Trigger.new, Trigger.oldMap);
       // WarrantyPriorTriggerHandler.handleWarrantyApproval(Trigger.new, Trigger.oldMap);
          WarrantyPriorTriggerHandler.createClaimAndClaimItem(Trigger.new, Trigger.oldMap); 
          DMLLogger.logChanges(Trigger.oldMap, Trigger.newMap, 'UPDATE', 'Warranty_Prior__c');
        
        // WarrantyPriorTriggerHandler.sendNotificationToDealer(Trigger.new,Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        // WarrantyPriorTriggerHandler.enforceCommentsOnRejection(Trigger.new,Trigger.oldMap);
    }
    
    if(trigger.IsBefore && trigger.IsDelete){
        DMLLogger.logChanges(Trigger.oldMap, null, 'DELETE', 'Warranty_Prior__c');
    }
    
}