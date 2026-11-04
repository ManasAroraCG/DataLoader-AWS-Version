public class DataFeedRecordTriggerHandler {

    // Use a static set to ensure we only try to start a batch once per transaction.
    private static Set<String> batchJobsStarted = new Set<String>();

    public static void startBatchProcessor(List<Data_Feed_Record__c> newRecords) {
        // We only care about the file name and parameters from the first record.
        // The batch will query for all the others.
        Data_Feed_Record__c sampleRecord = newRecords[0];

        String fileName = sampleRecord.File_Name__c;

        // Create a unique key for this batch execution
        String executionKey = fileName ;
        
        // Check if we've already started this job in this transaction
        if (batchJobsStarted.contains(executionKey)) {
            return;
        }

        // Check if a batch job for this file is already running or has been queued
        Integer runningJobs = [
            SELECT COUNT() 
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex' 
            AND (Status = 'Queued' OR Status = 'Processing')
            AND ApexClass.Name = 'ProcessDataFeed'
            // We need a way to see if it's for THIS file. This is tricky.
            // A common pattern is to "claim" the records in the batch constructor.
        ];

        if (runningJobs == 0) {
            Data_Feed_Job_Tracker__c jobTracker = [SELECT Id, Status__c, Operation_Type__c, Target_Object__c FROM Data_Feed_Job_Tracker__c WHERE File_Name__c = :fileName order by createddate desc LIMIT 1];
            If(jobTracker == null) {
                throw new AuraHandledException('No job tracker found for file: ' + fileName);
            }
            System.debug('Starting batch for file: ' + fileName + ' with operation type: ' + jobTracker.Operation_Type__c + ' and target object: ' + jobTracker.Target_Object__c);
            Database.executeBatch(new ProcessDataFeed(fileName, jobTracker.Operation_Type__c, jobTracker.Target_Object__c), 200);
            
            // Add to static set to prevent this trigger from trying to start it again in the same transaction
            batchJobsStarted.add(executionKey);
        }
    }
}