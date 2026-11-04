public class LookupUtility {
    @AuraEnabled
    public static List<FieldDescribe> getLookupFields(String parentObjectName, String lookupFieldName) {
        system.debug('Parent Object Name: ' + parentObjectName);
        system.debug('Lookup Field Name: ' + lookupFieldName);
        List<FieldDescribe> result = new List<FieldDescribe>();
        // Get the global describe map to access metadata of objects
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        // Check if the parent object exists
        if (!globalDescribe.containsKey(parentObjectName)) {
            System.debug('Parent object does not exist: ' + parentObjectName);
            return result;
        }

        // Get the describe result for the parent object
        Schema.SObjectType parentObjectType = globalDescribe.get(parentObjectName);
        Schema.DescribeSObjectResult parentDescribe = parentObjectType.getDescribe();

        // Get fields of the parent object
        Map<String, Schema.SObjectField> fieldsMap = parentDescribe.fields.getMap();

        // Check if the lookup field exists
        if (!fieldsMap.containsKey(lookupFieldName)) {
            System.debug('Lookup field does not exist: ' + lookupFieldName);
            return result;
        }

        // Get the describe result for the lookup field
        Schema.DescribeFieldResult lookupFieldDescribe = fieldsMap.get(lookupFieldName).getDescribe();

        // Retrieve referenced objects via the lookup field
        List<Schema.SObjectType> referenceObjects = lookupFieldDescribe.getReferenceTo();
        
        for (Schema.SObjectType reference : referenceObjects) {
            Schema.DescribeSObjectResult referenceDescribe = reference.getDescribe();
            
            System.debug('Referenced Object API Name: ' + referenceDescribe.getName());
            System.debug('Referenced Object Label: ' + referenceDescribe.getLabel());
            
            // Retrieve all fields of the referenced object
            Map<String, Schema.SObjectField> refFieldsMap = referenceDescribe.fields.getMap();
            for (String fieldName : refFieldsMap.keySet()) {
                System.debug('Field Name: ' + fieldName);
                System.debug('Field Label: ' + refFieldsMap.get(fieldName).getDescribe().getLabel());
                string referenceObjectFieldLabel = referenceDescribe.getLabel() + ' - ' +refFieldsMap.get(fieldName).getDescribe().getLabel();
                string referenceObjectFieldNameWithObject = referenceDescribe.getName() + '.' + fieldName;
                result.add(new FieldDescribe(referenceObjectFieldLabel, referenceObjectFieldNameWithObject));
            }
        }
        return result;
    }

    @AuraEnabled
    public static LookupDetail getLookupFieldsWithObjectName(String parentObjectName, String lookupFieldName) {
        system.debug('Parent Object Name: ' + parentObjectName);
        system.debug('Lookup Field Name: ' + lookupFieldName);
        
        LookupDetail lookupDetail = new LookupDetail();
        List<FieldDescribe> result = new List<FieldDescribe>();
        // Get the global describe map to access metadata of objects
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        // Check if the parent object exists
        if (!globalDescribe.containsKey(parentObjectName)) {
            System.debug('Parent object does not exist: ' + parentObjectName);
            return lookupDetail;
        }

        // Get the describe result for the parent object
        Schema.SObjectType parentObjectType = globalDescribe.get(parentObjectName);
        Schema.DescribeSObjectResult parentDescribe = parentObjectType.getDescribe();

        // Get fields of the parent object
        Map<String, Schema.SObjectField> fieldsMap = parentDescribe.fields.getMap();

        // Check if the lookup field exists
        if (!fieldsMap.containsKey(lookupFieldName)) {
            System.debug('Lookup field does not exist: ' + lookupFieldName);
            return lookupDetail;
        }

        // Get the describe result for the lookup field
        Schema.DescribeFieldResult lookupFieldDescribe = fieldsMap.get(lookupFieldName).getDescribe();

        // Retrieve referenced objects via the lookup field
        List<Schema.SObjectType> referenceObjects = lookupFieldDescribe.getReferenceTo();
        
        for (Schema.SObjectType reference : referenceObjects) {
            Schema.DescribeSObjectResult referenceDescribe = reference.getDescribe();            
            lookupDetail.lookUpObjectName = referenceDescribe.getName();
            
            System.debug('Referenced Object API Name: ' + referenceDescribe.getName());
            System.debug('Referenced Object Label: ' + referenceDescribe.getLabel());
            
            // Retrieve all fields of the referenced object
            Map<String, Schema.SObjectField> refFieldsMap = referenceDescribe.fields.getMap();
            for (String fieldName : refFieldsMap.keySet()) {
                System.debug('Field Name: ' + fieldName);
                System.debug('Field Label: ' + refFieldsMap.get(fieldName).getDescribe().getLabel());
                string referenceObjectFieldLabel = referenceDescribe.getLabel() + ' - ' +refFieldsMap.get(fieldName).getDescribe().getLabel();
                result.add(new FieldDescribe(referenceObjectFieldLabel, fieldName));
            }
        }
        lookupDetail.fieldList = result;

        return lookupDetail;
    }

    public class LookupDetail{
        @AuraEnabled public List<FieldDescribe> fieldList;
        @AuraEnabled public String lookUpObjectName;
    }

    public class FieldDescribe {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;

        public FieldDescribe(String label, String apiName) {
            this.label = label;
            this.apiName = apiName;
        }
    }
}