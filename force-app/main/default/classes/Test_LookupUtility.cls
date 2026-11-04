@isTest
public with sharing class Test_LookupUtility {
 
    // Positive Test Case: Valid parent object and lookup field
    @isTest
    static void testGetLookupFields_Positive() {
        // Setup: Use standard object and lookup field
        String parentObjectName = 'Case';
        String lookupFieldName = 'ContactId'; 

 
        Test.startTest();
        List<LookupUtility.FieldDescribe> fields = LookupUtility.getLookupFields(parentObjectName, lookupFieldName);
        Test.stopTest();
 
        System.assertNotEquals(0, fields.size(), 'Expected fields from referenced object');
        System.assertEquals(true, fields[0].label.contains('Contact'), 'Label should include referenced object name');
    }
 
    // Negative Test Case: Invalid parent object
    @isTest
    static void testGetLookupFields_InvalidParentObject() {
        String parentObjectName = 'InvalidObject';
        String lookupFieldName = 'ContactId';
 
        Test.startTest();
        List<LookupUtility.FieldDescribe> fields = LookupUtility.getLookupFields(parentObjectName, lookupFieldName);
        Test.stopTest();
 
        System.assertEquals(0, fields.size(), 'Expected empty list for invalid parent object');
    }
 
    // Negative Test Case: Invalid lookup field
    @isTest
    static void testGetLookupFields_InvalidLookupField() {
        String parentObjectName = 'Case';
        String lookupFieldName = 'InvalidField';
 
        Test.startTest();
        List<LookupUtility.FieldDescribe> fields = LookupUtility.getLookupFields(parentObjectName, lookupFieldName);
        Test.stopTest();
 
        System.assertEquals(0, fields.size(), 'Expected empty list for invalid lookup field');
    }
 
    // Positive Test Case for getLookupFieldsWithObjectName
    @isTest
    static void testGetLookupFieldsWithObjectName_Positive() {
        String parentObjectName = 'Case';
        String lookupFieldName = 'ContactId';
 
        Test.startTest();
        LookupUtility.LookupDetail detail = LookupUtility.getLookupFieldsWithObjectName(parentObjectName, lookupFieldName);
        Test.stopTest();
 
        System.assertNotEquals(null, detail.lookUpObjectName, 'Expected lookup object name');
        System.assertNotEquals(0, detail.fieldList.size(), 'Expected fields from referenced object');
    }
 
    // Negative Test Case for getLookupFieldsWithObjectName: Invalid parent object
    @isTest
    static void testGetLookupFieldsWithObjectName_InvalidParentObject() {
        String parentObjectName = 'InvalidObject';
        String lookupFieldName = 'ContactId';
 
        Test.startTest();
        LookupUtility.LookupDetail detail = LookupUtility.getLookupFieldsWithObjectName(parentObjectName, lookupFieldName);
        Test.stopTest();
 
        System.assertEquals(null, detail.lookUpObjectName, 'Expected null for invalid parent object');
        System.assertEquals(null, detail.fieldList, 'Expected null field list for invalid parent object');
    }
 
    // Negative Test Case for getLookupFieldsWithObjectName: Invalid lookup field
    @isTest
    static void testGetLookupFieldsWithObjectName_InvalidLookupField() {
        String parentObjectName = 'Case';
        String lookupFieldName = 'InvalidField';
 
        Test.startTest();
        LookupUtility.LookupDetail detail = LookupUtility.getLookupFieldsWithObjectName(parentObjectName, lookupFieldName);
        Test.stopTest();
 
        System.assertEquals(null, detail.lookUpObjectName, 'Expected null for invalid lookup field');
        System.assertEquals(null, detail.fieldList, 'Expected null field list for invalid lookup field');
    }
}