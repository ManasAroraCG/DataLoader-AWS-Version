@isTest
public class Test_CSVConfigurationMapping {
    @isTest
    static void testCreateConfigurationSimple(){
        //1. Prepare test data - Simple non-lookup mapping
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'migration.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping = new CSVConfigurationMapping.ConfigurationMapping();
        mapping.csvFieldName = 'Name';
        mapping.selectedField = 'Name';
        mapping.isLookup = false;

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping };

        //2. Execute the test
        Test.startTest();
        CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        Test.stopTest();

        //3. Verify the results
        List<CgInfinity__Data_Feed_Mapping__c> results = [
            SELECT Id, CgInfinity__File_Name__c, CgInfinity__SObject_API_Name__c, CgInfinity__Field_to_update__c, CgInfinity__File_Column_Name__c, CgInfinity__Is_Lookup__c, CgInfinity__Operation__c, CgInfinity__Lookup_Return_Field__c
            FROM CgInfinity__Data_Feed_Mapping__c 
            WHERE CgInfinity__File_Name__c = 'migration.csv'
        ];

        System.assertEquals(1, results.size(), 'One mapping record should be created');
        System.assertEquals('Account', results[0].CgInfinity__SObject_API_Name__c, 'Object name should be Account');
        System.assertEquals('Insert', results[0].CgInfinity__Operation__c, 'CgInfinity__Operation__c should be Insert');
        System.assertEquals(null, results[0].CgInfinity__Lookup_Return_Field__c, 'CgInfinity__Lookup_Return_Field__c should be Id for all mappings');
        System.assertEquals('Name', results[0].CgInfinity__Field_to_update__c, 'Field should be Name');
        System.assertEquals('Name', results[0].CgInfinity__File_Column_Name__c, 'CSV field name should be Name');
        System.assertEquals(false, results[0].CgInfinity__Is_Lookup__c, 'CgInfinity__Is_Lookup__c should be false');
    }

    @isTest
    static void testCreateConfigurationWithLookupOldFields() {
        // Test with lookup using old field names (selectedLookupFields, lookupObject)
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Contact';
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'contact_migration.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping = new CSVConfigurationMapping.ConfigurationMapping();
        mapping.csvFieldName = 'AccountId';
        mapping.selectedField = 'AccountId';
        mapping.isLookup = true;
        mapping.selectedLookupFields = 'Id';
        mapping.lookupObject = 'Account';
        mapping.whereClause = 'Name = "Test Account"';
        mapping.targetObject = ''; // Empty, should use lookupObject
        mapping.matchField = ''; // Empty, should use selectedLookupFields
        mapping.returnField = ''; // Empty, should default to Id

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping };

        Test.startTest();
        CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        Test.stopTest();

        List<CgInfinity__Data_Feed_Mapping__c> results = [
            SELECT Id, CgInfinity__File_Name__c, CgInfinity__SObject_API_Name__c, CgInfinity__Field_to_update__c, CgInfinity__File_Column_Name__c, CgInfinity__Is_Lookup__c, CgInfinity__Lookup_Object_Name__c, CgInfinity__Lookup_Field__c, CgInfinity__Lookup_Filter_Criteria__c, CgInfinity__Operation__c, CgInfinity__Lookup_Return_Field__c
            FROM CgInfinity__Data_Feed_Mapping__c 
            WHERE CgInfinity__File_Name__c = 'contact_migration.csv'
        ];

        System.assertEquals(1, results.size(), 'One mapping record should be created');
        CgInfinity__Data_Feed_Mapping__c rec = results[0];
        System.assertEquals('Contact', rec.CgInfinity__SObject_API_Name__c, 'Object name should be Contact');
        System.assertEquals('Insert', rec.CgInfinity__Operation__c, 'CgInfinity__Operation__c should be Insert');
        System.assertEquals('AccountId', rec.CgInfinity__Field_to_update__c, 'Field should be AccountId');
        System.assertEquals('AccountId', rec.CgInfinity__File_Column_Name__c, 'CSV field name should be AccountId');
        System.assertEquals(true, rec.CgInfinity__Is_Lookup__c, 'CgInfinity__Is_Lookup__c should be true');
        System.assertEquals('Account', rec.CgInfinity__Lookup_Object_Name__c, 'Lookup object should be Account (from fallback)');
        System.assertEquals('Id', rec.CgInfinity__Lookup_Field__c, 'Lookup field should be Id (from fallback)');
        System.assertEquals('Name = "Test Account"', rec.CgInfinity__Lookup_Filter_Criteria__c, 'Where clause should match');
        System.assertEquals('Id', rec.CgInfinity__Lookup_Return_Field__c, 'CgInfinity__Lookup_Return_Field__c should default to Id');
    }

    @isTest
    static void testCreateConfigurationWithLookupNewFields() {
        // Test with lookup using new field names (targetObject, matchField, returnField)
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Opportunity';
        wrapper.operationType = 'Update';
        wrapper.fileName = 'opp_migration.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping = new CSVConfigurationMapping.ConfigurationMapping();
        mapping.csvFieldName = 'AccountId';
        mapping.selectedField = 'AccountId';
        mapping.isLookup = true;
        mapping.targetObject = 'Account'; // New field
        mapping.matchField = 'ExternalId__c'; // New field
        mapping.returnField = 'RecordTypeId'; // New field
        mapping.whereClause = 'Industry = "Technology"';
        mapping.selectedLookupFields = 'Id'; // Will be overridden
        mapping.lookupObject = 'Contact'; // Will be overridden

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping };

        Test.startTest();
        CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        Test.stopTest();

        List<CgInfinity__Data_Feed_Mapping__c> results = [
            SELECT Id, CgInfinity__File_Name__c, CgInfinity__SObject_API_Name__c, CgInfinity__Field_to_update__c, CgInfinity__File_Column_Name__c, CgInfinity__Is_Lookup__c, CgInfinity__Lookup_Object_Name__c, CgInfinity__Lookup_Field__c, CgInfinity__Lookup_Filter_Criteria__c, CgInfinity__Operation__c, CgInfinity__Lookup_Return_Field__c
            FROM CgInfinity__Data_Feed_Mapping__c 
            WHERE CgInfinity__File_Name__c = 'opp_migration.csv'
        ];

        System.assertEquals(1, results.size(), 'One mapping record should be created');
        CgInfinity__Data_Feed_Mapping__c rec = results[0];
        System.assertEquals('Opportunity', rec.CgInfinity__SObject_API_Name__c, 'Object name should be Opportunity');
        System.assertEquals('Update', rec.CgInfinity__Operation__c, 'CgInfinity__Operation__c should be Update');
        System.assertEquals('Account', rec.CgInfinity__Lookup_Object_Name__c, 'Lookup object should be Account (from new field)');
        System.assertEquals('ExternalId__c', rec.CgInfinity__Lookup_Field__c, 'Lookup field should be ExternalId__c (from new field)');
        System.assertEquals('RecordTypeId', rec.CgInfinity__Lookup_Return_Field__c, 'CgInfinity__Lookup_Return_Field__c should be RecordTypeId');
        System.assertEquals('Industry = "Technology"', rec.CgInfinity__Lookup_Filter_Criteria__c, 'Where clause should match');
    }

    @isTest
    static void testCreateConfigurationUpsertWithUniqueKey() {
        // Test Upsert operation with unique key flag
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Upsert';
        wrapper.fileName = 'upsert.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping1 = new CSVConfigurationMapping.ConfigurationMapping();
        mapping1.csvFieldName = 'ExternalId__c';
        mapping1.selectedField = 'ExternalId__c';
        mapping1.isLookup = false;
        mapping1.isUniqueKey = true; // This should be set in the record

        CSVConfigurationMapping.ConfigurationMapping mapping2 = new CSVConfigurationMapping.ConfigurationMapping();
        mapping2.csvFieldName = 'Name';
        mapping2.selectedField = 'Name';
        mapping2.isLookup = false;
        mapping2.isUniqueKey = false;

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping1, mapping2 };

        Test.startTest();
        CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        Test.stopTest();

        List<CgInfinity__Data_Feed_Mapping__c> results = [
            SELECT Id, CgInfinity__File_Name__c, CgInfinity__Operation__c, CgInfinity__Field_to_update__c, CgInfinity__Is_Unique_Key__c
            FROM CgInfinity__Data_Feed_Mapping__c 
            WHERE CgInfinity__File_Name__c = 'upsert.csv'
            ORDER BY CgInfinity__Field_to_update__c
        ];

        System.assertEquals(2, results.size(), 'Two mapping records should be created');
        System.assertEquals('Upsert', results[0].CgInfinity__Operation__c, 'Operation should be Upsert');
        System.assertEquals('ExternalId__c', results[0].CgInfinity__Field_to_update__c, 'First field should be ExternalId__c');
        System.assertEquals(true, results[0].CgInfinity__Is_Unique_Key__c, 'First mapping should have CgInfinity__Is_Unique_Key__c = true');
        System.assertEquals('Name', results[1].CgInfinity__Field_to_update__c, 'Second field should be Name');
    }

    @isTest
    static void testCreateConfigurationMultipleMappings() {
        // Test with multiple mapping entries including both lookup and non-lookup
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Update';
        wrapper.fileName = 'multi.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping1 = new CSVConfigurationMapping.ConfigurationMapping();
        mapping1.csvFieldName = 'Name';
        mapping1.selectedField = 'Name';
        mapping1.isLookup = false;

        CSVConfigurationMapping.ConfigurationMapping mapping2 = new CSVConfigurationMapping.ConfigurationMapping();
        mapping2.csvFieldName = 'AccountId';
        mapping2.selectedField = 'AccountId';
        mapping2.isLookup = true;
        mapping2.targetObject = 'Account';
        mapping2.matchField = 'AccountNumber';
        mapping2.returnField = 'Id';

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping1, mapping2 };

        Test.startTest();
        CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        Test.stopTest();

        List<CgInfinity__Data_Feed_Mapping__c> results = [
            SELECT Id, CgInfinity__File_Name__c, CgInfinity__SObject_API_Name__c, CgInfinity__Field_to_update__c, CgInfinity__File_Column_Name__c, CgInfinity__Operation__c, CgInfinity__Is_Lookup__c, CgInfinity__Lookup_Object_Name__c
            FROM CgInfinity__Data_Feed_Mapping__c 
            WHERE CgInfinity__File_Name__c = 'multi.csv' ORDER BY CgInfinity__Field_to_update__c
        ];

        System.assertEquals(2, results.size(), 'Two mapping records should be created');
        System.assertEquals('AccountId', results[0].CgInfinity__Field_to_update__c, 'First should be AccountId (alphabetical)');
        System.assertEquals(true, results[0].CgInfinity__Is_Lookup__c, 'First mapping should be a lookup');
        System.assertEquals('Account', results[0].CgInfinity__Lookup_Object_Name__c, 'Lookup object should be Account');
        System.assertEquals('Name', results[1].CgInfinity__Field_to_update__c, 'Second should be Name');
        System.assertEquals(false, results[1].CgInfinity__Is_Lookup__c, 'Second mapping should not be a lookup');
        System.assertEquals('Update', results[0].CgInfinity__Operation__c, 'Operation should be propagated to each record');
    }

    // Error Scenario Tests
    @isTest
    static void testCreateConfigurationNullWrapper() {
        // Test with null wrapper
        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An exception should have been thrown for null wrapper');
    }

    @isTest
    static void testCreateConfigurationEmptyObjectName() {
        // Test with empty object name
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = ''; // Empty
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'test.csv';
        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>();

        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An exception should have been thrown for empty object name');
    }

    @isTest
    static void testCreateConfigurationEmptyOperationType() {
        // Test with empty operation type
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = ''; // Empty
        wrapper.fileName = 'test.csv';
        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>();

        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An exception should have been thrown for empty operation type');
    }

    @isTest
    static void testCreateConfigurationNullMapping() {
        // Test with null mapping list
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'test.csv';
        wrapper.mapping = null; // Null

        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An exception should have been thrown for null mapping');
    }

    @isTest
    static void testCreateConfigurationEmptyMappingList() {
        // Test with empty mapping list
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'empty.csv';
        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>();

        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'An exception should have been thrown for empty mapping list');
    }

    @isTest
    static void testCreateConfigurationMissingCsvFieldName() {
        // Test with missing CSV field name
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'test.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping = new CSVConfigurationMapping.ConfigurationMapping();
        mapping.csvFieldName = ''; // Empty
        mapping.selectedField = 'Name';
        mapping.isLookup = false;

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping };

        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An exception should have been thrown for missing CSV field name');
    }

    @isTest
    static void testCreateConfigurationMissingSelectedField() {
        // Test with missing selected field
        CSVConfigurationMapping.ConfigurationWrapper wrapper = new CSVConfigurationMapping.ConfigurationWrapper();
        wrapper.objectName = 'Account';
        wrapper.operationType = 'Insert';
        wrapper.fileName = 'test.csv';

        CSVConfigurationMapping.ConfigurationMapping mapping = new CSVConfigurationMapping.ConfigurationMapping();
        mapping.csvFieldName = 'Name';
        mapping.selectedField = ''; // Empty
        mapping.isLookup = false;

        wrapper.mapping = new List<CSVConfigurationMapping.ConfigurationMapping>{ mapping };

        Test.startTest();
        boolean exceptionThrown = false;
        try {
            CSVConfigurationMapping.createConfiguration(JSON.serialize(wrapper));
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An exception should have been thrown for missing selected field');
    }
}