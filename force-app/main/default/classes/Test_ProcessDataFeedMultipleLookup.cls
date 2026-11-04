@isTest
public class Test_ProcessDataFeedMultipleLookup {
    @testSetup
    static void setup() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'Account_Data 1',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'Account_Data 1',
            CgInfinity__File_Column_Name__c = 'Name,Account Number',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'ParentId',
            CgInfinity__Lookup_Object_Name__c = 'Account',
            CgInfinity__Lookup_Field__c = 'name,accountnumber',
            CgInfinity__Lookup_Return_Field__c = 'Id',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = true
        );
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'Account_Data 1',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Is_Lookup__c = false,
            CgInfinity__Operation__c = 'Insert'
        );
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'Account_Data 1',
            CgInfinity__File_Column_Name__c = 'Account Number',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'AccountNumber',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
        insert new Account(Name = 'Grand Hotels & Resorts Ltd', AccountNumber = 'CD439877');
        insert new Account(Name = 'sForce', AccountNumber = 'CC567842');
    }
    @isTest
    static void testBatchProcessing()
    {
        List<String> jsonDataList = new List<String>{
            '{"Name,Account Number":"Grand Hotels & Resorts Ltd,CD439877","Name":"Grand Hotels & Resorts Ltd","Account Number":"CD439877"}',
            '{"Name,Account Number":"sForce,CC567842","Name":"sForce","Account Number":"CC567842"}'
        };
        for (String jsonData : jsonDataList) {
            insert new CgInfinity__Data_Feed_Record__c(
                CgInfinity__File_Name__c = 'Account_Data 1',
                CgInfinity__Data_Feed_Record_JSON__c = jsonData,
                CgInfinity__Is_Processed__c = false
            );
        }
        // Run batch
        ProcessDataFeed batch = new ProcessDataFeed('Account_Data 1', 'Insert', 'Account');
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        // Verify CgInfinity__Data_Feed_Record__c is marked processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c, CgInfinity__Error_Message__c
            FROM CgInfinity__Data_Feed_Record__c
            WHERE CgInfinity__File_Name__c = 'Account_Data 1'
        ];
        System.assert(processedRecords.size() > 0, 'Should process one or more records');
        for (CgInfinity__Data_Feed_Record__c rec : processedRecords) {
            System.assertEquals(true, rec.CgInfinity__Is_Processed__c, 'Record should be marked processed');
            System.assertEquals(null, rec.CgInfinity__Error_Message__c, 'No error expected on processed records');
        }
        List<Account> accounts = [SELECT Name, CgInfinity__Operating_Hour__c, AccountNumber FROM Account WHERE Name IN ('Grand Hotels & Resorts Ltd', 'sForce')];
        System.assertEquals(4, accounts.size(), 'Two Accounts should be created');
        }
}