@isTest
public class Test_DataFeedRecordTriggerHandler {

    @isTest
    static void testStartBatchProcessor() {
        // 1. Insert a job tracker record
        CgInfinity__Data_Feed_Job_Tracker__c jobTracker = new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'testFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
        insert jobTracker;

        // 2. Insert CgInfinity__Data_Feed_Record__c records
        List<CgInfinity__Data_Feed_Record__c> feedRecords = new List<CgInfinity__Data_Feed_Record__c>();
        feedRecords.add(new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'testFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = '{"Name":"Dummy Account"}',
            CgInfinity__Is_Processed__c = false
        ));
        insert feedRecords;

        // 3. Call the handler method
        Test.startTest();
        DataFeedRecordTriggerHandler.startBatchProcessor(feedRecords);
        Test.stopTest();

        // 4. Assert that a batch job was queued
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ProcessDataFeed'
        ];
        System.assert(jobs.size() > 0, 'Batch job should be queued');
        System.assertEquals('ProcessDataFeed', jobs[0].ApexClass.Name);
    }
}