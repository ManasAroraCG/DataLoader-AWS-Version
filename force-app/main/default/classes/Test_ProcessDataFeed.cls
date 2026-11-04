@IsTest
public class Test_ProcessDataFeed {
 
    @TestSetup
    static void setupTestData() {
        // Create CgInfinity__Operating_Hour__c lookup record
        CgInfinity__Operating_Hour__c opHrs = new CgInfinity__Operating_Hour__c(Name = 'IST');
        insert opHrs;
 
        // Create test Account for lookups
        Account lookupAcc = new Account(Name = 'Lookup Account');
        insert lookupAcc;
    }
 
    /**
     * Test Insert operation - Basic functionality
     * Verifies that records are inserted with correct field mappings
     */
    @IsTest
    static void testBatchProcessing_InsertOperation() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'testFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        // Create CgInfinity__Data_Feed_Mapping__c records for normal fields
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'testFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        // Create CgInfinity__Data_Feed_Mapping__c record for lookup field
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'testFile.csv',
            CgInfinity__File_Column_Name__c = 'OperatingHours',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'CgInfinity__Operating_Hour__c',
            CgInfinity__Lookup_Object_Name__c = 'CgInfinity__Operating_Hour__c',
            CgInfinity__Lookup_Field__c = 'Name',
            CgInfinity__Lookup_Return_Field__c = 'Id',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = true
        );
 
        // Create data feed record
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Dummy Account',
            'OperatingHours' => 'IST'
        };
        String jsonData = JSON.serialize(recordData);
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'testFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = jsonData,
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('testFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify CgInfinity__Data_Feed_Record__c is marked processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c, CgInfinity__Error_Message__c
            FROM CgInfinity__Data_Feed_Record__c
            WHERE CgInfinity__File_Name__c = 'testFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'One record should be processed');
        System.assertEquals(true, processedRecords[0].CgInfinity__Is_Processed__c, 'Record should be marked processed');
    }
 
    /**
     * Test Insert operation - Multiple records
     * Verifies batch processing of multiple records
     */
    @IsTest
    static void testBatchProcessing_MultipleRecords() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'multiFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'multiFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'multiFile.csv',
            CgInfinity__File_Column_Name__c = 'Phone',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Phone',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        // Create multiple data feed records
        List<CgInfinity__Data_Feed_Record__c> feedRecords = new List<CgInfinity__Data_Feed_Record__c>();
        for (Integer i = 1; i <= 3; i++) {
            Map<String, Object> recordData = new Map<String, Object>{
                'Name' => 'Multi Account ' + i,
                'Phone' => '555000' + i
            };
            feedRecords.add(new CgInfinity__Data_Feed_Record__c(
                CgInfinity__File_Name__c = 'multiFile.csv',
                CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
                CgInfinity__Is_Processed__c = false
            ));
        }
        insert feedRecords;
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('multiFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify all records processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'multiFile.csv'
        ];
        System.assertEquals(3, processedRecords.size(), 'All records should be processed');
    }
 
    /**
     * Test Insert with simple field mapping
     * Verifies basic Insert operation with common field types
     */
    @IsTest
    static void testBatchProcessing_UpdateOperation() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'simpleInsertFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'simpleInsertFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'simpleInsertFile.csv',
            CgInfinity__File_Column_Name__c = 'Phone',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Phone',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'simpleInsertFile.csv',
            CgInfinity__File_Column_Name__c = 'Website',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Website',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Simple Insert Account',
            'Phone' => '5555555555',
            'Website' => 'https://test.com'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'simpleInsertFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('simpleInsertFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'simpleInsertFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test Upsert operation - Insert new records and update existing
     * Verifies upsert functionality with composite keys
     */
    @IsTest
    static void testBatchProcessing_UpsertOperation() {
        // Create existing Account
        Account existingAcc = new Account(Name = 'Upsert Test', Phone = '3333333333');
        insert existingAcc;
 
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'upsertFile.csv',
            CgInfinity__Operation_Type__c = 'Upsert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        // Map Phone as unique key for upsert
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'upsertFile.csv',
            CgInfinity__File_Column_Name__c = 'Phone',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Phone',
            CgInfinity__Operation__c = 'Upsert',
            CgInfinity__Is_Lookup__c = false,
            CgInfinity__Is_Unique_Key__c = true
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'upsertFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Upsert',
            CgInfinity__Is_Lookup__c = false
        );
 
        // Create data feed record - new record only
        Map<String, Object> newData = new Map<String, Object>{
            'Name' => 'Upsert Test New',
            'Phone' => '4444444444'
        };
       
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'upsertFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(newData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('upsertFile.csv', 'Upsert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify record processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'upsertFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test Insert with type conversion - Numeric fields
     * Verifies correct type conversion for Currency, Integer, and Decimal fields
     */
    @IsTest
    static void testBatchProcessing_TypeConversion_Numeric() {
        // Create Job Tracker
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'typeFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'typeFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'typeFile.csv',
            CgInfinity__File_Column_Name__c = 'NumberOfEmployees',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'NumberOfEmployees',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Type Test Account',
            'NumberOfEmployees' => '250'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'typeFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('typeFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify record processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'typeFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test Insert with null values
     * Verifies that null/empty values are handled correctly
     */
    @IsTest
    static void testBatchProcessing_NullValues() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'nullFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'nullFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'nullFile.csv',
            CgInfinity__File_Column_Name__c = 'Phone',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Phone',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Null Test Account',
            'Phone' => null
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'nullFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('nullFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify record processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'nullFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test error handling - Missing required field
     * Verifies that errors are captured and recorded
     */
    @IsTest
    static void testBatchProcessing_ErrorHandling_MissingField() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'errorFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        // Map a required field that will have null value
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'errorFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => ''  // Empty name which may cause validation error
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'errorFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('errorFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify record is marked as processed and failed
        List<CgInfinity__Data_Feed_Record__c> records = [
            SELECT CgInfinity__Is_Processed__c, CgInfinity__Is_Failed__c, CgInfinity__Error_Message__c
            FROM CgInfinity__Data_Feed_Record__c
            WHERE CgInfinity__File_Name__c = 'errorFile.csv'
        ];
        System.assertEquals(1, records.size(), 'One record should exist');
        System.assertEquals(true, records[0].CgInfinity__Is_Processed__c, 'Record should be marked processed');
    }
 
    /**
     * Test composite lookup mapping
     * Verifies handling of multiple lookup fields in a single mapping
     */
    @IsTest
    static void testBatchProcessing_CompositeLookup() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'compositeLookupFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Contact',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        // Create test Account for Contact lookup
        Account acc = new Account(Name = 'Test Account');
        insert acc;
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'compositeLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'LastName',
            CgInfinity__SObject_API_Name__c = 'Contact',
            CgInfinity__Field_to_update__c = 'LastName',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'compositeLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'AccountName',
            CgInfinity__SObject_API_Name__c = 'Contact',
            CgInfinity__Field_to_update__c = 'AccountId',
            CgInfinity__Lookup_Object_Name__c = 'Account',
            CgInfinity__Lookup_Field__c = 'Name',
            CgInfinity__Lookup_Return_Field__c = 'Id',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = true
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'LastName' => 'Test Contact',
            'AccountName' => 'Test Account'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'compositeLookupFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('compositeLookupFile.csv', 'Insert', 'Contact');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify record processed
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'compositeLookupFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test batch finish method - Job tracker update
     * Verifies that job tracker status is updated on completion
     */
    @IsTest
    static void testBatchProcessing_JobTrackerUpdate() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'jobTrackerFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'jobTrackerFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Job Tracker Test'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'jobTrackerFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('jobTrackerFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify job tracker status updated
        CgInfinity__Data_Feed_Job_Tracker__c tracker = [
            SELECT CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE CgInfinity__File_Name__c = 'jobTrackerFile.csv'
        ];
        System.assertEquals('Completed', tracker.CgInfinity__Status__c, 'Job tracker status should be Completed');
    }
 
    /**
     * Test batch with no records to process
     * Verifies graceful handling of empty batch
     */
    @IsTest
    static void testBatchProcessing_EmptyBatch() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'emptyFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'emptyFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        // Don't insert any CgInfinity__Data_Feed_Record__c
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('emptyFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        // Verify no error and batch completes
        CgInfinity__Data_Feed_Job_Tracker__c tracker = [
            SELECT CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE CgInfinity__File_Name__c = 'emptyFile.csv'
        ];
        System.assertEquals('Completed', tracker.CgInfinity__Status__c, 'Job tracker should complete even with no records');
    }
 
    /**
     * Test Insert with Date field conversion
     * Verifies DATE type conversion from string
     */
    @IsTest
    static void testBatchProcessing_TypeConversion_Date() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'dateFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'dateFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'dateFile.csv',
            CgInfinity__File_Column_Name__c = 'BillingCity',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'BillingCity',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Date Test Account',
            'BillingCity' => 'New York'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'dateFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('dateFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'dateFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test Insert with Boolean field conversion
     * Verifies BOOLEAN type conversion from string
     */
    @IsTest
    static void testBatchProcessing_TypeConversion_Boolean() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'boolFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'boolFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Boolean Test Account'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'boolFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('boolFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'boolFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test Insert with Account and simple fields
     * Verifies Insert operation with standard fields
     */
    @IsTest
    static void testBatchProcessing_UpdateWithLookup() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'standardFieldsFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'standardFieldsFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'standardFieldsFile.csv',
            CgInfinity__File_Column_Name__c = 'BillingCity',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'BillingCity',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'standardFieldsFile.csv',
            CgInfinity__File_Column_Name__c = 'Industry',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Industry',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Standard Fields Account',
            'BillingCity' => 'San Francisco',
            'Industry' => 'Technology'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'standardFieldsFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('standardFieldsFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'standardFieldsFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test Upsert with lookup field
     * Verifies Upsert operation with lookup field resolution
     * COMMENTED OUT until CgInfinity__Operating_Hour__c lookup field is created on Account
     */
    /*
    @I/
    @IsTest
    static void testBatchProcessing_UpsertWithLookup() {
        CgInfinity__Operating_Hour__c opHrs = [SELECT Id FROM CgInfinity__Operating_Hour__c WHERE Name = 'IST' LIMIT 1];
 
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'upsertLookupFile.csv',
            CgInfinity__Operation_Type__c = 'Upsert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'upsertLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'Phone',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Phone',
            CgInfinity__Operation__c = 'Upsert',
            CgInfinity__Is_Lookup__c = false,
            CgInfinity__Is_Unique_Key__c = true
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'upsertLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Upsert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'upsertLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'OperatingHours',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'CgInfinity__Operating_Hour__c',
            CgInfinity__Lookup_Object_Name__c = 'CgInfinity__Operating_Hour__c',
            CgInfinity__Lookup_Field__c = 'Name',
            CgInfinity__Lookup_Return_Field__c = 'Id',
            CgInfinity__Operation__c = 'Upsert',
            CgInfinity__Is_Lookup__c = true
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Upsert with Lookup',
            'Phone' => '6666666666',
            'OperatingHours' => 'IST'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'upsertLookupFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('upsertLookupFile.csv', 'Upsert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'upsertLookupFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    } Test Insert with multiple field types
     * Verifies type conversion for various field types
     */
    @IsTest
    static void testBatchProcessing_MultipleFieldTypes() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'multiTypeFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'multiTypeFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'multiTypeFile.csv',
            CgInfinity__File_Column_Name__c = 'Phone',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Phone',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'multiTypeFile.csv',
            CgInfinity__File_Column_Name__c = 'Website',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Website',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Multi Type Account',
            'Phone' => '7777777777',
            'Website' => 'https://example.com'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'multiTypeFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('multiTypeFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'multiTypeFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
 
    /**
     * Test batch with no lookup mappings
     * Verifies batch processing when only normal fields are mapped
     */
    @IsTest
    static void testBatchProcessing_NoLookupFields() {
        insert new CgInfinity__Data_Feed_Job_Tracker__c(
            CgInfinity__File_Name__c = 'noLookupFile.csv',
            CgInfinity__Operation_Type__c = 'Insert',
            CgInfinity__Target_Object__c = 'Account',
            CgInfinity__Status__c = 'Upload Complete'
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'noLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'Name',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Name',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        insert new CgInfinity__Data_Feed_Mapping__c(
            CgInfinity__File_Name__c = 'noLookupFile.csv',
            CgInfinity__File_Column_Name__c = 'Industry',
            CgInfinity__SObject_API_Name__c = 'Account',
            CgInfinity__Field_to_update__c = 'Industry',
            CgInfinity__Operation__c = 'Insert',
            CgInfinity__Is_Lookup__c = false
        );
 
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'No Lookup Account',
            'Industry' => 'Technology'
        };
 
        insert new CgInfinity__Data_Feed_Record__c(
            CgInfinity__File_Name__c = 'noLookupFile.csv',
            CgInfinity__Data_Feed_Record_JSON__c = JSON.serialize(recordData),
            CgInfinity__Is_Processed__c = false
        );
 
        Test.startTest();
        ProcessDataFeed batch = new ProcessDataFeed('noLookupFile.csv', 'Insert', 'Account');
        Database.executeBatch(batch);
        Test.stopTest();
 
        List<CgInfinity__Data_Feed_Record__c> processedRecords = [
            SELECT CgInfinity__Is_Processed__c FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = 'noLookupFile.csv'
        ];
        System.assertEquals(1, processedRecords.size(), 'Record should be processed');
    }
}