public with sharing class CSVDataController {
    
    @AuraEnabled(cacheable=true)
   public static List<SObjectDescribe> getObjects() {
        List<SObjectDescribe> result = new List<SObjectDescribe>();
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            for (Schema.SObjectType objType : gd.values()) {
                Schema.DescribeSObjectResult describe = objType.getDescribe();
                // Exclude system/internal objects, only include queryable and not deprecated objects
                if (!describe.isCustomSetting() && !describe.isDeprecatedAndHidden() && describe.isQueryable()
                    && !describe.getName().startsWith('Aura')
                    && !describe.getName().startsWith('Feed')
                    && !describe.getName().startsWith('UserProv')
                    && !describe.getName().endsWith('Share')
                    && !describe.getName().endsWith('History')
                    && !describe.getName().endsWith('ChangeEvent')
                    && !describe.getName().endsWith('Feed')
                    && !describe.getName().endsWith('Tag')
                    && !describe.getName().endsWith('ViewStat')
                    && !describe.getName().endsWith('VoteStat')
                    && !describe.getName().endsWith('DataStat')
                    && !describe.getName().endsWith('CleanInfo')
                    && !describe.getName().endsWith('DuplicateRule')
                    && !describe.getName().endsWith('DuplicateRecordItem')
                    && !describe.getName().endsWith('DuplicateRecordSet')
                    && !describe.getName().endsWith('DuplicateJob')
                    && !describe.getName().endsWith('DuplicateRuleFilter')
                    && !describe.getName().endsWith('DuplicateRuleMatchRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleSetItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleSetRule')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleSetRuleItem')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleSetRuleSet')
                    && !describe.getName().endsWith('DuplicateRuleMatchRuleSetRuleSetRuleSetRuleSetRuleSetRuleSetRuleSetItem')
                ) {
                    result.add(new SObjectDescribe(describe.getLabel(), describe.getName()));
                }
            }
        } catch (Exception ex) {
            System.debug('Exception: ' + ex.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldDescribe> getFields(String objectName) {
        List<FieldDescribe> result = new List<FieldDescribe>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        
        if (objType != null) {
            Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
            
            for (Schema.SObjectField field : fieldsMap.values()) {
                if (field.getDescribe().isCreateable() || field.getDescribe().getName() == 'Id') {
                    Boolean isLookup = isLookupField(field);
                    String relatedObject = '';
                    
                    // Get the related object name for lookup fields
                    if (isLookup) {
                        List<Schema.SObjectType> refList = field.getDescribe().getReferenceTo();
                        if (refList != null && refList.size() > 0) {
                            relatedObject = refList.get(0).getDescribe().getName();
                        }
                    }
                    
                    result.add(new FieldDescribe(
                        field.getDescribe().getLabel(),
                        field.getDescribe().getName(),
                        isLookup,
                        relatedObject
                    ));
                }
            }
        }
        
        return result;
	}

    public static Boolean isLookupField(Schema.SObjectField field) {
        // Get field description
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        
        // Check if the field is a reference type
        if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
            // Check if it is a lookup by verifying relationship order is null
            if (fieldDescribe.getRelationshipOrder() == null) {
                return true; // It's a lookup field
            }
        }
        else if (field.getDescribe().getName() == 'Id') {
            return true; // Not a lookup field
        }
        return false; // Not a lookup field
    }
    

    @AuraEnabled
    public static List<Map<String, Object>> fetchData(String objectName, List<String> fields) {
        String query = 'SELECT ' + String.join(fields, ',') + ' FROM ' + objectName;
        List<SObject> records = Database.query(query);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (SObject record : records) {
            Map<String, Object> row = new Map<String, Object>();
            for (String field : fields) {
                row.put(field, record.get(field));
            }
            results.add(row);
        }
        return results;
    }

    @AuraEnabled
    public static String generateCSV(String objectName, List<String> fieldNames) {
        system.debug('Object Name: ' + objectName);
        system.debug('Field Names: ' + fieldNames);
        try {
            // Validate input
            if (String.isBlank(objectName) || fieldNames == null || fieldNames.isEmpty()) {
                throw new IllegalArgumentException('Object name and field names cannot be empty.');
            }

            // Build dynamic SOQL query
        String fields = String.join(fieldNames, ',');
        String query = 'SELECT ' + fields + ' FROM ' + objectName;
        
        List<SObject> records = Database.query(query);
        system.debug('Query: ' + query);
        system.debug('Records: ' + records);
        

        // Generate CSV string
        String csvString = String.join(fieldNames, ',') + '\n';
        for (SObject record : records) {
            List<String> row = new List<String>();
            for (String field : fieldNames) {

        // Handle relationship fields (e.g., "Account.Name")
        if (field.contains('.')) {
            SObject temp = record;
            List<String> fieldParts = field.split('\\.');
            
            // Traverse relationships (all parts except last)
            for (Integer i = 0; i < fieldParts.size() - 1; i++) {
                temp = temp.getSObject(fieldParts[i]);
                if (temp == null) break; // Handle missing relationships
            }
            
            // Get final field value
            Object value = (temp != null) 
                ? temp.get(fieldParts[fieldParts.size()-1]) 
                : null;
            row.add(String.valueOf(value));
        } 
        // Handle regular fields
        else {
            row.add(String.valueOf(record.get(field)));
        }
            }
            csvString += String.join(row,',' ) + '\n';
        }
        
        return csvString;
        } catch (IllegalArgumentException e) {
            System.debug('Error: ' + e.getMessage());
            return null;
        }
        
    }

    public class SObjectDescribe {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;

        public SObjectDescribe(String label, String apiName) {
            this.label = label;
            this.apiName = apiName;
        }
    }
    
    public class FieldDescribe {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean isLookup;
        @AuraEnabled public String relatedObject;

        public FieldDescribe(String label, String apiName, Boolean isLookup) {
            this.label = label;
            this.apiName = apiName;
            this.isLookup = isLookup;
            this.relatedObject = '';
        }

        public FieldDescribe(String label, String apiName, Boolean isLookup, String relatedObject) {
            this.label = label;
            this.apiName = apiName;
            this.isLookup = isLookup;
            this.relatedObject = relatedObject;
        }
    }
}