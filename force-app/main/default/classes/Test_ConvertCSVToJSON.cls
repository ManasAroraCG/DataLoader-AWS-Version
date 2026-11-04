@isTest
public class Test_ConvertCSVToJSON {
    @isTest
    static void testParseCSV_Basic() {
        //Normal CSV String
        string csvData = 'Name,Age,Location\nNeha,20,India\nxyz,25,USA';
        Blob csvBlob=Blob.valueOf(csvData);

        List<Object> result = ConvertCSVToJSON.parseCSV(csvBlob);
        System.assertEquals(2,result.size(),'Should use and parse two records');

        Map<String, Object> firstRecord = (Map<String,Object>) result[0];
        System.assertEquals('Neha',firstRecord.get('Name'), 'First Record name Should be same Nehha');
        System.assertEquals('20',firstRecord.get('Age'),'Age should be as same as 20');
        System.assertEquals('India',firstRecord.get('Location'),'Location should be India');

        Map<String, Object> secondRecord = (Map<String,Object>) result[1];
        System.assertEquals('xyz',secondRecord.get('Name'), 'Second Record name Should be same xyz');
        System.assertEquals('25',secondRecord.get('Age'),'Age should be as same as 25');
        System.assertEquals('USA',secondRecord.get('Location'),'Location should be USA');
    }
    
    @isTest
    static void testEmptyCSV() {
        // Empty CSV string
        String csvData = '';
        Blob csvBlob = Blob.valueOf(csvData);
        
        List<Object> result = ConvertCSVToJSON.parseCSV(csvBlob);
        System.assertEquals(0, result.size(), 'Expected empty list for empty CSV');
    }

    @isTest
    static void testSingleLineCSV(){
        // CSV with only headers
        String csvData = 'Name,Age,Location\n';
        Blob csvBlob = Blob.valueOf(csvData);
        
        List<Object> result = ConvertCSVToJSON.parseCSV(csvBlob);
        System.assertEquals(0, result.size(), 'Expected empty list for CSV with only headers');
    }

    // @isTest
    // static void testCSVMissingValues() {
    // // CSV with missing values
    //     String csvData = 'Name,Age,Location\nNeha,,India\nxyz,25,';
    //     Blob csvBlob = Blob.valueOf(csvData);
    //     List<Object> result = ConvertCSVToJSON.parseCSV(csvBlob);
    //     System.assertEquals(2, result.size(), 'Should parse two records even with missing values');
    
    //     Map<String, Object> firstRecord = (Map<String,Object>) result[0];
    //     System.assertEquals('Neha', firstRecord.get('Name'), 'First Record name should be Neha');
    //     System.assertEquals('', firstRecord.get('Age'), 'Age should be empty string for missing value');
    //     System.assertEquals('India', firstRecord.get('Location'), 'Location should be India');
    
    //     Map<String, Object> secondRecord = (Map<String,Object>) result[1];
    //     System.assertEquals('xyz', secondRecord.get('Name'), 'Second Record name should be xyz');
    //     System.assertEquals('25', secondRecord.get('Age'), 'Age should be 25');
    //     System.assertEquals('', secondRecord.get('Location'), 'Location should be empty string for missing value');
    // }
}