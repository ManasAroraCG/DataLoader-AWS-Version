// Keep this trigger on Data_Feed_Record__c
trigger DataFeedRecordTrigger on Data_Feed_Record__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        // The handler's only job is to start the batch, and only do it ONCE per file.
        //DataFeedRecordTriggerHandler.startBatchProcessor(Trigger.new);
    }
}