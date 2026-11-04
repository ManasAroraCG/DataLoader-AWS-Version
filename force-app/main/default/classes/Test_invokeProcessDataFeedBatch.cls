@isTest
public with sharing class Test_invokeProcessDataFeedBatch 
{
    
    @isTest
    public static void Test_invokeProcessDataFeedBatch() 
    {
        insert new Data_Feed_Job_Tracker__c(File_Name__c = 'data.csv',Operation_Type__c = 'Insert',Target_Object__c = 'Account',Status__c = 'Upload Complete');
        Test.startTest();
        CSVUploaderController.invokeProcessDataFeedBatch('data.csv', 'Insert', 'Account');
        Test.stopTest();
    }
}