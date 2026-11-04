@isTest
public class Test_DataFeedJobTrackerTriggerHandler {

    @isTest
    static void testStartBatchProcessor_StatusReady() {
        CgInfinity__Data_Feed_Job_Tracker__c jobTracker = new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__Status__c = 'Ready for Processing',
            CgInfinity__File_Name__c = 'test.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account'
        );
        insert jobTracker;
        List<CgInfinity__Data_Feed_Job_Tracker__c> newRecords = [
            SELECT Id, CgInfinity__Status__c, CgInfinity__File_Name__c, CgInfinity__Operation_Type__c, CgInfinity__Target_Object__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE Id =: jobTracker.Id
        ];

        Test.startTest();
        DataFeedJobTrackerTriggerHandler.startBatchProcessor(newRecords);
        Test.stopTest();

        CgInfinity__Data_Feed_Job_Tracker__c updatedJob = [
            SELECT CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE Id = :jobTracker.Id
        ];
        System.assertEquals('Ready for Processing', updatedJob.CgInfinity__Status__c);
    }

    @isTest
    static void testStartBatchProcessor_StatusNotReady() {
        CgInfinity__Data_Feed_Job_Tracker__c jobTracker = new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__Status__c = 'Upload Complete',
            CgInfinity__File_Name__c = 'test.csv',
            CgInfinity__Operation_Type__c = 'Update',
            CgInfinity__Target_Object__c = 'Account'
        );
        insert jobTracker;

        List<CgInfinity__Data_Feed_Job_Tracker__c> newRecords = [
            SELECT Id, CgInfinity__Status__c, CgInfinity__File_Name__c, CgInfinity__Operation_Type__c, CgInfinity__Target_Object__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE Id = :jobTracker.Id
        ];

        Test.startTest();
        DataFeedJobTrackerTriggerHandler.startBatchProcessor(newRecords);
        Test.stopTest();

        CgInfinity__Data_Feed_Job_Tracker__c updatedJob = [
            SELECT CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE Id = :jobTracker.Id
        ];
        System.assertEquals('Completed', updatedJob.CgInfinity__Status__c);
    }
}