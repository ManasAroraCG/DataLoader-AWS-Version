trigger DataFeedJobTrigger on CgInfinity__Data_Feed_Job_Tracker__c (after update) {
    DataFeedJobTrackerTriggerHandler.startBatchProcessor(
        Trigger.new,
        Trigger.oldMap
    );
}