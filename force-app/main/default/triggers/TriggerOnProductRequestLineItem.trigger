trigger TriggerOnProductRequestLineItem on ProductRequestLineItem (After insert, After Update,Before update,before Delete, before insert) {
    if (trigger.IsAfter && (trigger.IsInsert || trigger.IsUpdate)) {
        ProductRequestLineItemHandler.productLineItemUnitPrice(trigger.new);
    }
    if(trigger.IsBefore && trigger.isUpdate){
       // ProductRequestLineItemHandler.throwErrorIftheRecordIsUpdatedByDMSUserWhenParentRecordIsNotInNewStatus(trigger.new);
       JobCardRecordLock.PreventUpdateForJobCardStatus(trigger.new);
    }
    if(trigger.IsBefore && trigger.isDelete){
      //  ProductRequestLineItemHandler.throwErrorIftheRecordIsUpdatedByDMSUserWhenParentRecordIsNotInNewStatus(trigger.old);
      JobCardRecordLock.PreventUpdateForJobCardStatus(trigger.new);
    }
    if(trigger.IsBefore && (trigger.IsInsert)){
        JobCardRecordLock.PreventUpdateForJobCardStatus(trigger.new);
    }
}