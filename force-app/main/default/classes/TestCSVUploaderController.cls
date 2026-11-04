@isTest
public with sharing class TestCSVUploaderController {

    @isTest
    public static void testUploadToApex() {
        list<String>jsonData = new List<String>
        {
            '{"Name":"Test Feed","Description":"Test"}',
            '{"Name":"Test Feed","Description":"Test"}'
        };
        String fileName = 'test.json';
        
        Test.startTest();
        CSVUploaderController.uploadToApex(jsonData, fileName);
        Test.stopTest();
        List<Data_Feed_Record__c> inserted = [SELECT Id, Data_Feed_Record_JSON__c, File_Name__c FROM Data_Feed_Record__c];
        System.assertEquals(2, inserted.size(), 'two records should be inserted');
    }

    @isTest
    public static void TestUpdateDataFeedJobTrackerStatus()
    {
        String fileName = 'test.csv';
        String status = 'Ready for Processing';
        String operationType = 'Insert';
        String targetObject = 'Account';

        Test.startTest();

        CSVUploaderController.updateDataFeedJobTrackerStatus(status, fileName, operationType, targetObject);

        Test.stopTest();

        
        List<Data_Feed_Job_Tracker__c> trackers = [SELECT Id, File_Name__c, Status__c, Operation_Type__c, Target_Object__c FROM Data_Feed_Job_Tracker__c WHERE File_Name__c = :fileName];

        System.assertEquals(1, trackers.size(), 'A new job tracker should be created');
    }

    @isTest
    public static void TestUpdateDataFeedJobTrackerStatus_Existing()
    {
        String fileName = 'test.csv';
        String status = 'Ready for Processing';
        String operationType = 'Insert';
        String targetObject = 'Account';
        
        Data_Feed_Job_Tracker__c existing = new Data_Feed_Job_Tracker__c(File_Name__c = fileName,Status__c = status, Operation_Type__c = operationType,Target_Object__c = targetObject);
        insert existing;

        
        Test.startTest();
        CSVUploaderController.updateDataFeedJobTrackerStatus('Completed', fileName, 'Update', 'Account');
        Test.stopTest();

        
        List<Data_Feed_Job_Tracker__c> trackers = [SELECT Id, File_Name__c, Status__c FROM Data_Feed_Job_Tracker__c WHERE File_Name__c = :fileName];
        System.assertEquals(1, trackers.size(), 'Should not create a new tracker when one already exists');
        System.assertEquals('Completed', trackers[0].Status__c, 'Existing tracker status should be updated');

    }

}