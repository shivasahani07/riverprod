trigger ClaimItemTrigger on ClaimItem (after update, before insert, before update, before delete) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        ClaimItemTriggerHandler.processClaimUpdates(Trigger.new);
        DMLLogger.logChanges(Trigger.oldMap, Trigger.newMap, 'UPDATE', 'ClaimItem');
    }
    
    if(trigger.IsBefore && trigger.IsDelete){
        DMLLogger.logChanges(Trigger.oldMap, null, 'DELETE', 'ClaimItem');
    }
}