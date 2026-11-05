public class FetchAllObjects {
    public static List<String> getAllObjects() {
        // Fetch all objects using Schema.getGlobalDescribe()
        Map<String, Schema.SObjectType> allObjects = Schema.getGlobalDescribe();
        List<String> listOfObjects = new List<String>();
        // Iterate through the map and print object names
        for (String objectName : allObjects.keySet()) {
            System.debug('Object Name: ' + objectName);
            listOfObjects.add(objectName);
        }
        
        return listOfObjects;
    }
    
    public static Map<string, string> getFields(string objectName){
        Map<string, string> fieldApiAndLabelMapping = new Map<string, string>();
        
        objectName = String.isBlank(objectName) ? 'Account' : objectName;

        // Get the global describe map for all objects
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        
        // Retrieve the describe information for the specified object
        Schema.SObjectType sObjectType = schemaMap.get(objectName);
        Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
        
        // Get a map of fields for the object
        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        
        // Iterate through the fields and retrieve API names and labels
        for (String fieldApiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldApiName).getDescribe();
            String fieldLabel = fieldDescribe.getLabel(); // Get the label name
            System.debug('API Name: ' + fieldApiName + ', Label: ' + fieldLabel);
            fieldApiAndLabelMapping.put(fieldApiName, fieldLabel);
        }
		return fieldApiAndLabelMapping;
    }
    
     @AuraEnabled
    public static String generateCSV(String objectName, List<String> fieldNames) {
        // Build dynamic SOQL query
        String fields = String.join(fieldNames, ',');
        String query = 'SELECT ' + fields + ' FROM ' + objectName;
        
        List<SObject> records = Database.query(query);

        // Generate CSV string
        String csvString = String.join(fieldNames, ',') + '\n';
        for (SObject record : records) {
            List<String> row = new List<String>();
            for (String field : fieldNames) {
                row.add(String.valueOf(record.get(field)));
            }
            csvString += String.join(row,',' ) + '\n';
        }
        
        return csvString;
    }
}