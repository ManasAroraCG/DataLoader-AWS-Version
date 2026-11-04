@isTest
public class Test_CSVUploaderController {

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account for CSV');
        insert acc;

        // Create test Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert con;

        // Create test Lead
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company'
        );
        insert lead;
    }

    /**
     * Test uploadToApex() method - Basic functionality
     * Verifies that JSON records are inserted into CgInfinity__Data_Feed_Record__c
     */
    @IsTest
    static void testUploadToApex_BasicFunctionality() {
        List<String> jsonDataList = new List<String>{
            '{"Name":"Account1","Phone":"1234567890"}',
            '{"Name":"Account2","Phone":"0987654321"}'
        };
        String fileName = 'accounts_upload.csv';

        Test.startTest();
        CSVUploaderController.uploadToApex(jsonDataList, fileName);
        Test.stopTest();

        List<CgInfinity__Data_Feed_Record__c> records = [
            SELECT Id, CgInfinity__Data_Feed_Record_JSON__c, CgInfinity__File_Name__c 
            FROM CgInfinity__Data_Feed_Record__c 
            WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(2, records.size(), 'Two records should be inserted');
        for (CgInfinity__Data_Feed_Record__c record : records) {
            System.assertEquals(fileName, record.CgInfinity__File_Name__c, 'File name should be set correctly');
            System.assertNotEquals(null, record.CgInfinity__Data_Feed_Record_JSON__c, 'JSON data should not be null');
        }
    }

    /**
     * Test uploadToApex() method - Large batch processing
     * Verifies that large number of records can be processed
     */
    @IsTest
    static void testUploadToApex_LargeBatch() {
        List<String> jsonDataList = new List<String>();
        Integer batchSize = 500;

        for (Integer i = 0; i < batchSize; i++) {
            jsonDataList.add('{"Name":"Record' + i + '","Value":"' + i + '"}');
        }
        String fileName = 'large_batch.csv';

        Test.startTest();
        CSVUploaderController.uploadToApex(jsonDataList, fileName);
        Test.stopTest();

        List<CgInfinity__Data_Feed_Record__c> records = [
            SELECT Id FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(batchSize, records.size(), 'All ' + batchSize + ' records should be inserted');
    }

    /**
     * Test uploadToApex() method - Complex JSON data
     * Verifies that complex nested JSON is stored correctly
     */
    @IsTest
    static void testUploadToApex_ComplexJSON() {
        String complexJson = '{"Name":"TestAccount","Address":{"Street":"123 Main St","City":"Anytown","Zip":"12345"},"Contacts":[{"Name":"John"},{"Name":"Jane"}]}';
        List<String> jsonDataList = new List<String>{ complexJson };
        String fileName = 'complex_json.csv';

        Test.startTest();
        CSVUploaderController.uploadToApex(jsonDataList, fileName);
        Test.stopTest();

        List<CgInfinity__Data_Feed_Record__c> records = [
            SELECT Id, CgInfinity__Data_Feed_Record_JSON__c 
            FROM CgInfinity__Data_Feed_Record__c 
            WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(1, records.size(), 'One record should be inserted');
        System.assertEquals(complexJson, records[0].CgInfinity__Data_Feed_Record_JSON__c, 'Complex JSON should be preserved');
    }

    /**
     * Test uploadToApex() method - Duplicate file names
     * Verifies that multiple uploads with same file name create separate records
     */
    @IsTest
    static void testUploadToApex_DuplicateFileNames() {
        String fileName = 'duplicate_file.csv';
        List<String> jsonDataList1 = new List<String>{ '{"Name":"FirstBatch"}' };
        List<String> jsonDataList2 = new List<String>{ '{"Name":"SecondBatch"}' };

        Test.startTest();
        CSVUploaderController.uploadToApex(jsonDataList1, fileName);
        CSVUploaderController.uploadToApex(jsonDataList2, fileName);
        Test.stopTest();

        List<CgInfinity__Data_Feed_Record__c> records = [
            SELECT Id, CgInfinity__Data_Feed_Record_JSON__c 
            FROM CgInfinity__Data_Feed_Record__c 
            WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(2, records.size(), 'Two batches should be inserted for same file name');
    }

    /**
     * Test updateDataFeedJobTrackerStatus() method - Create new tracker with Running status
     * Verifies that a new tracker is created with 'Running' status
     */
    @IsTest
    static void testUpdateDataFeedJobTrackerStatus_CreateNewTrackerWithRunningStatus() {
        String fileName = 'new_tracker_running.csv';
        String status = 'Running';
        String operationType = 'Insert';
        String targetObject = 'Account';

        Test.startTest();
        CSVUploaderController.updateDataFeedJobTrackerStatus(status, fileName, operationType, targetObject);
        Test.stopTest();

        List<CgInfinity__Data_Feed_Job_Tracker__c> trackers = [
            SELECT Id, CgInfinity__File_Name__c, CgInfinity__Status__c, CgInfinity__Operation_Type__c, CgInfinity__Target_Object__c 
            FROM CgInfinity__Data_Feed_Job_Tracker__c 
            WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(1, trackers.size(), 'One tracker should be created');
        System.assertEquals(status, trackers[0].CgInfinity__Status__c, 'Status should be Running');
        System.assertEquals(operationType, trackers[0].CgInfinity__Operation_Type__c, 'Operation type should match');
        System.assertEquals(targetObject, trackers[0].CgInfinity__Target_Object__c, 'Target object should match');
    }

    /**
     * Test updateDataFeedJobTrackerStatus() method - Multiple status updates
     * Verifies that tracker status progresses through the workflow
     */
    @IsTest
    static void testUpdateDataFeedJobTrackerStatus_MultipleStatusUpdates() {
        String fileName = 'multiple_status_updates.csv';
        
        Test.startTest();
        // Progress through workflow: Running -> Upload Complete -> Completed
        CSVUploaderController.updateDataFeedJobTrackerStatus('Running', fileName, 'Insert', 'Lead');
        CSVUploaderController.updateDataFeedJobTrackerStatus('Upload Complete', fileName, 'Insert', 'Lead');
        CSVUploaderController.updateDataFeedJobTrackerStatus('Completed', fileName, 'Insert', 'Lead');
        Test.stopTest();

        List<CgInfinity__Data_Feed_Job_Tracker__c> trackers = [
            SELECT Id, CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(1, trackers.size(), 'Only one tracker should exist after multiple updates');
        System.assertEquals('Completed', trackers[0].CgInfinity__Status__c, 'Final status should be Completed');
    }

    /**
     * Test updateDataFeedJobTrackerStatus() method - Ready for Processing status
     * Verifies that tracker can be created with 'Ready for Processing' status
     */
    @IsTest
    static void testUpdateDataFeedJobTrackerStatus_ReadyForProcessingStatus() {
        String fileName = 'ready_for_processing.csv';
        String status = 'Ready for Processing';
        String operationType = 'Update';
        String targetObject = 'Account';

        Test.startTest();
        CSVUploaderController.updateDataFeedJobTrackerStatus(status, fileName, operationType, targetObject);
        Test.stopTest();

        List<CgInfinity__Data_Feed_Job_Tracker__c> trackers = [
            SELECT Id, CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE CgInfinity__File_Name__c = :fileName
        ];

        System.assertEquals(1, trackers.size(), 'Tracker should be created');
        System.assertEquals(status, trackers[0].CgInfinity__Status__c, 'Status should be Ready for Processing');
    }

    /**
     * Test updateDataFeedJobTrackerStatus() method - Error handling
     * Verifies that exceptions are properly caught and thrown as AuraHandledException
     */
    @IsTest
    static void testUpdateDataFeedJobTrackerStatus_ErrorHandling() {
        String fileName = 'error_test.csv';
        String operationType = 'Insert';
        String targetObject = 'Account';

        Test.startTest();
        try {
            // First call succeeds and creates tracker
            CSVUploaderController.updateDataFeedJobTrackerStatus('Running', fileName, operationType, targetObject);
            
            // Try to update with null status to trigger an exception
            CSVUploaderController.updateDataFeedJobTrackerStatus(null, fileName, operationType, targetObject);
            
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            // Verify exception is properly wrapped
            System.assertNotEquals(null, e.getMessage(), 'Error message should not be null');
            System.assert(e.getMessage().length() > 0, 'Error message should contain details');
        }
        Test.stopTest();
    }
    /**
     * Test getPresignedUrl() method - Valid request
     * Verifies that presigned URL is returned correctly
     */
    @IsTest
    static void testGetPresignedUrl_ValidRequest() {
        String fileName = 'test_file.csv';
        String mockUrl = 'https://s3.amazonaws.com/bucket/test_file.csv?signature=abc123';

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockUrl, 200, true));

        Test.startTest();
        String presignedUrl = CSVUploaderController.getPresignedUrl(fileName);
        Test.stopTest();

        System.assertNotEquals(null, presignedUrl, 'Presigned URL should not be null');
        System.assertEquals(mockUrl, presignedUrl, 'Presigned URL should match');
    }

    /**
     * Test uploadToApex() and updateDataFeedJobTrackerStatus() integration
     * Verifies that upload and tracker update work together in the complete workflow
     */
    @IsTest
    static void testUploadToApex_WithCompleteWorkflow() {
        String fileName = 'integration_workflow.csv';
        List<String> jsonDataList = new List<String>{
            '{"Name":"Record1"}',
            '{"Name":"Record2"}'
        };
        String operationType = 'Insert';
        String targetObject = 'Account';

        Test.startTest();
        // Upload CSV records
        CSVUploaderController.uploadToApex(jsonDataList, fileName);
        
        // Initialize tracker with Running status
        CSVUploaderController.updateDataFeedJobTrackerStatus('Running', fileName, operationType, targetObject);
        
        // Update to Upload Complete (triggers batch processing via trigger)
        CSVUploaderController.updateDataFeedJobTrackerStatus('Upload Complete', fileName, operationType, targetObject);
        Test.stopTest();

        // Verify records were uploaded
        List<CgInfinity__Data_Feed_Record__c> records = [SELECT Id FROM CgInfinity__Data_Feed_Record__c WHERE CgInfinity__File_Name__c = :fileName];
        System.assertEquals(2, records.size(), 'Records should be uploaded');
        
        // Verify tracker was created
        List<CgInfinity__Data_Feed_Job_Tracker__c> trackers = [SELECT Id, CgInfinity__Status__c FROM CgInfinity__Data_Feed_Job_Tracker__c WHERE CgInfinity__File_Name__c = :fileName];
        System.assertEquals(1, trackers.size(), 'Tracker should be created');
        System.assertEquals('Completed', trackers[0].CgInfinity__Status__c, 'Tracker status should be Completed');
    }

    /**
     * Mock HTTP Response class for testing
     */
    private class MockHttpResponse implements HttpCalloutMock {
        private String presignedUrl;
        private Integer statusCode;
        private Boolean includeUrl;

        public MockHttpResponse(String presignedUrl, Integer statusCode, Boolean includeUrl) {
            this.presignedUrl = presignedUrl;
            this.statusCode = statusCode;
            this.includeUrl = includeUrl;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);

            if (statusCode == 200 && includeUrl) {
                Map<String, Object> responseBody = new Map<String, Object>{
                    'presignedUrl' => presignedUrl
                };
                res.setBody(JSON.serialize(responseBody));
            } else {
                res.setBody('{"error":"Invalid response"}');
            }

            return res;
        }
    }
}