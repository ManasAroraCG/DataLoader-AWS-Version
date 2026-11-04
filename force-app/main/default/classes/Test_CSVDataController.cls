@IsTest
public class Test_CSVDataController {

    @testSetup
    static void Data() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;
    }

    @IsTest
    static void testGetObjects() {
        Test.startTest();
        List<CSVDataController.SObjectDescribe> objects = CSVDataController.getObjects();
        Test.stopTest();

        System.assertNotEquals(0, objects.size(), 'Objects List Should not be Empty');

        List<String> expectedObjects = new List<String>{
            'Account','Contact','Lead','Opportunity','User','Task','Event','Case'
        };

        List<String> apiNames = new List<String>();
        for (CSVDataController.SObjectDescribe sObj : objects) {
            apiNames.add(sObj.apiName);
        }
        for (String expected : expectedObjects) {
            System.assert(apiNames.contains(expected), 'Expected Object ' + expected + ' not found');
        }
    }

    @IsTest
    static void testGetFields_P() {
        Test.startTest();
        List<CSVDataController.FieldDescribe> fields = CSVDataController.getFields('Account');
        Test.stopTest();

        System.assert(fields.size() > 0, 'Field List returned');
    }

    @IsTest
    static void testGetFields_N() {
        Test.startTest();
        List<CSVDataController.FieldDescribe> fields = CSVDataController.getFields('Fake_Account');
        Test.stopTest();

        System.assertEquals(0, fields.size(), 'No field Available for this object');
    }

    @IsTest
    static void testIsLookupField_P() {
        Schema.SobjectField field = Account.CgInfinity__Operating_Hour__c;
        Test.startTest();
        Boolean isLookup = CSVDataController.isLookupField(field);
        Test.stopTest();
        System.assertEquals(true, isLookup, 'Yes it is a lookup');
    }

    @IsTest
    static void testIsLookupField_N() {
        Schema.SobjectField field = Account.Name;
        Test.startTest();
        Boolean isLookup = CSVDataController.isLookupField(field);
        Test.stopTest();
        System.assertEquals(false, isLookup, 'it is not a lookup');
    }

    @IsTest
    static void testFetchData() {
        List<String> fields = new List<String>{ 'Id', 'Name' };
        Test.startTest();
        List<Map<String, Object>> result = CSVDataController.fetchData('Account', fields);
        Test.stopTest();
        System.assert(result.size() > 0, 'At least one record');
        System.assert(result[0].containsKey('Name'), 'Result should contain Name key');
    }

    @IsTest
    static void testGenerateCSV() {
        List<String> fieldNames = new List<String>{ 'Id', 'Name', 'Account.Name' };
        Test.startTest();
        String csv = CSVDataController.generateCSV('Contact', fieldNames);
        Test.stopTest();

        System.assert(csv != null, 'CSV should not be null');

        System.assert(csv.startsWith('Id,Name,Account.Name'), 'CSV header should match field names');

        List<String> rows = csv.split('\n');
        System.assertEquals(2, rows.size(), 'CSV should have 2 rows');//header+contact

        List<String> cols = rows[1].split(',');
        System.assertEquals(3, cols.size(), 'Data row should have 3 columns');
        System.assertEquals('Test Account', cols[2], 'Account.Name should be "Test Account"');
    }
}