@isTest
private class Test_FetchAllObjects{

    @isTest
    static void testGetAllObjectsPositive(){
        List<String> allObjects = FetchAllObjects.getAllObjects();
        System.assertNotEquals(0,allObjects.size(),'The list of objects should not be empty');
        System.assert(allObjects.contains('account'),'The list should contain Account object');
    }

    @isTest
    static void testGetFieldsPositive(){
        Map<string,string> fieldMap = FetchAllObjects.getFields('Account');
        System.assertNotEquals(0,fieldMap.size(),'Field map should not be empty for Account object');
        System.assert(fieldMap.containsKey('name'),'Field map should contain Name field');
        System.assertEquals('Account Name',fieldMap.get('name'),'Field label for Name should be Account Name');
    }

    @isTest
    static void testGetFieldsNegative(){
        try{
            Map<String,String> fieldMap = FetchAllObjects.getFields('Invalid_Object');
            System.assert(false, 'Expected exception for invalid object name');
        } catch (Exception e) {
            System.assertNotEquals(null, e, 'Exception should be thrown for invalid object name');
        }}

    @isTest
    static void testGetFieldsNullObject(){
            Map<String,String> fieldMap = FetchAllObjects.getFields(null);
            System.assertNotEquals(0,fieldMap.size(),'Field map should not be empty for null value');
            System.assert(fieldMap.containsKey('name'),'Field map should contain Name field');
            System.assertEquals('Account Name',fieldMap.get('name'),'Field label for Name should be Account Name');  
    }

    @isTest
    static void testGetFieldsBlankObject(){
            Map<String,String> fieldMapBlank = FetchAllObjects.getFields('');
            System.assertNotEquals(0,fieldMapBlank.size(),'Field map should not be empty for Empty value');
            System.assert(fieldMapBlank.containsKey('name'),'Field map should contain Name field');
            System.assertEquals('Account Name',fieldMapBlank.get('name'),'Field label for Name should be Account Name');  
    }
    
    @isTest
    static void testGenerateCSVPositive(){
        string objectName = 'Account';
        List<String> fieldNames = new List<String>{'Id','Name'};
        string csvResult = FetchAllObjects.generateCSV(objectName,fieldNames);
        System.assertNotEquals(null,csvResult,'CSV result should not be null');
        System.assert(csvResult.startsWith('Id,Name'),'CSV should start with header row');
    }

    @isTest
    static void testGenerateCSVMissingField(){
        string objectName = 'Account';
        List<String> fieldNames = new List<String>{'Id','Non_Existent_Field__c'};
        try{
            string csvResult = FetchAllObjects.generateCSV(objectName,fieldNames);
            System.assert(false,'Should throw exception for non-existent field');
        }catch(Exception e){
            System.assertNotEquals(null, e, 'Exception should be thrown for non-existent field');
        }
    }

    @isTest
    static void testGenerateCSVMissingObject(){
        string objectName = 'Non_Existent_Object__c';
        List<String> fieldNames = new List<String>{'Id','Name'};
        try{
            string csvResult = FetchAllObjects.generateCSV(objectName,fieldNames);
            System.assert(false,'Should throw exception for non-existent object');
        }catch(Exception e){
            System.assertNotEquals(null, e, 'Exception should be thrown for non-existent object');
        }
    }

    @isTest
    static void testGenerateCSVEmptyFieldList(){
        string objectName = 'Account';
        List<String> fieldNames = new List<String>();
        try{
            string csvResult = FetchAllObjects.generateCSV(objectName,fieldNames);
            System.assert(false,'Should throw exception for empty field list');
        }catch(Exception e){
            System.assertNotEquals(null, e, 'Exception should be thrown for empty field list');
        }
    }

    @isTest
    static void testGenerateCSVNullFieldList(){
        string objectName = null;
        List<String> fieldNames = null;
        try{
            string csvResult = FetchAllObjects.generateCSV(objectName,fieldNames);
            System.assert(false,'Should throw exception for null values');
        }catch(Exception e){
            System.assertNotEquals(null, e, 'Exception should be thrown for null values');
        }
    }
}