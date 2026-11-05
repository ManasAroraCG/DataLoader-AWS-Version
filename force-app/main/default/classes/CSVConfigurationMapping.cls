public without sharing class CSVConfigurationMapping {
    @AuraEnabled
    public static String createConfiguration(String wrapperJson) {
        try {
            system.debug('Received JSON: ' + wrapperJson);
            ConfigurationWrapper wrapper = (ConfigurationWrapper) JSON.deserialize(wrapperJson, ConfigurationWrapper.class);
            // Validate input
            if (wrapper == null) {
                throw new AuraHandledException('Configuration wrapper is null');
            }
            
            if (String.isEmpty(wrapper.objectName)) {
                throw new AuraHandledException('Object name is required');
            }
            
            if (String.isEmpty(wrapper.operationType)) {
                throw new AuraHandledException('Operation type is required');
            }
            
            // mappingName validation
            if (String.isBlank(wrapper.mappingName)) {
                throw new AuraHandledException('Mapping Name is required');
            }

            if (wrapper.mapping == null || wrapper.mapping.isEmpty()) {
                throw new AuraHandledException('No mappings provided');
            }
            
            System.debug('Creating configuration mappings...');
            system.debug('wrapper: ' + wrapper);
            system.debug('wrapper.objectName: ' + wrapper.objectName);
            system.debug('wrapper.operationType: ' + wrapper.operationType);
            system.debug('wrapper.fileName: ' + wrapper.fileName);
            system.debug('wrapper.mapping size: ' + wrapper.mapping.size());
            
            List<CgInfinity__Data_Feed_Mapping__c> mappings = new List<CgInfinity__Data_Feed_Mapping__c>();
            for (ConfigurationMapping mp : wrapper.mapping) {
                system.debug('Processing mapping: ' + mp);
                
                if (String.isEmpty(mp.csvFieldName)) {
                    throw new AuraHandledException('CSV Field Name is required in mapping');
                }
                
                if (String.isEmpty(mp.selectedField)) {
                    throw new AuraHandledException('Selected Field is required for CSV column: ' + mp.csvFieldName);
                }
                
                CgInfinity__Data_Feed_Mapping__c mapping = new CgInfinity__Data_Feed_Mapping__c();
                mapping.CgInfinity__Operation__c = wrapper.operationType;
                mapping.CgInfinity__File_Name__c = wrapper.fileName;
                mapping.CgInfinity__Field_to_update__c = mp.selectedField;
                mapping.CgInfinity__File_Column_Name__c = mp.csvFieldName;
                mapping.CgInfinity__SObject_API_Name__c = wrapper.objectName;

                // mapping name set up(tan)
                mapping.CgInfinity__Mapping_Name__c = wrapper.mappingName;

                if (mp.isLookup == true) {
                    mapping.CgInfinity__Lookup_Object_Name__c = String.isNotBlank(mp.targetObject) ? mp.targetObject : mp.lookupObject;
                    mapping.CgInfinity__Lookup_Field__c = String.isNotBlank(mp.matchField) ? mp.matchField : mp.selectedLookupFields;
                    mapping.CgInfinity__Lookup_Return_Field__c = String.isNotBlank(mp.returnField) ? mp.returnField : 'Id';
                }
                mapping.CgInfinity__Is_Lookup__c = (mp.isLookup == true);
                mapping.CgInfinity__Lookup_Filter_Criteria__c = String.isNotBlank(mp.whereClause) ? mp.whereClause : '';
                // Set the unique key flag for Upsert operations
                if (wrapper.operationType == 'Upsert' && mp.isUniqueKey == true) {
                    mapping.CgInfinity__Is_Unique_Key__c = true;
                }
                mappings.add(mapping);
                system.debug('mapping created: ' + mapping);
            }

            if(mappings.size() == 0) {
                throw new AuraHandledException('No valid mappings to insert');
            }
            
            insert mappings;

            system.debug('Successfully inserted ' + mappings.size() + ' mappings');

            // Retrieve the generated Configuration Display Name
            CgInfinity__Data_Feed_Mapping__c savedMapping = [
                SELECT Id, CgInfinity__Configuration_Display_Name__c
                FROM CgInfinity__Data_Feed_Mapping__c
                WHERE Id = :mappings[0].Id
                LIMIT 1
            ];

            String configurationDisplayName =
                savedMapping.CgInfinity__Configuration_Display_Name__c;

            if (String.isBlank(configurationDisplayName)) {
                throw new AuraHandledException(
                    'Configuration Display Name could not be generated.'
                );
            }

            System.debug(
                'Generated Configuration Display Name: ' +
                configurationDisplayName
            );

            return configurationDisplayName;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dmlEx) {
            system.debug('DML Error: ' + dmlEx.getMessage());
            throw new AuraHandledException('DML Error: ' + dmlEx.getDmlMessage(0));
        } catch (Exception e) {
            system.debug('Error in createConfiguration: ' + e.getMessage() + ' Line: ' + e.getLineNumber());
            throw new AuraHandledException('Error: ' + e.getTypeName() + ' - ' + e.getMessage());
        }
    }

    // Duplicate mapping name checking(tan)
    @AuraEnabled
    public static Boolean mappingNameExists(String mappingName) {
        if (String.isBlank(mappingName)) {
            return false;
        }

        String trimmedName = mappingName.trim();

        List<CgInfinity__Data_Feed_Mapping__c> existingMappings = [
            SELECT Id
            FROM CgInfinity__Data_Feed_Mapping__c
            WHERE Mapping_Name__c = :trimmedName
            LIMIT 1
        ];

        return !existingMappings.isEmpty();
    }


    // Existing mapping names fetch (tan)
    @AuraEnabled(cacheable=true)
    public static List<String> getExistingMappings(
        String objectName,
        String operationType
    ) {
        Set<String> mappingNames = new Set<String>();

        if (String.isBlank(objectName) || String.isBlank(operationType)) {
            return new List<String>();
        }

        for (CgInfinity__Data_Feed_Mapping__c ar : [
            SELECT CgInfinity__Configuration_Display_Name__c
            FROM CgInfinity__Data_Feed_Mapping__c
            WHERE CgInfinity__Configuration_Display_Name__c != null
            AND CgInfinity__SObject_API_Name__c = :objectName
            AND CgInfinity__Operation__c = :operationType
            ORDER BY CreatedDate DESC
        ]) {
            mappingNames.add(ar.CgInfinity__Configuration_Display_Name__c);
        }

        List<String> result = new List<String>(mappingNames);
        result.sort();

        System.debug('Mapping Names --> ' + result);
        return result;
    }

    
    // Mapping details fetch for data preview (tan)
    @AuraEnabled(cacheable=true)
    public static List<CgInfinity__Data_Feed_Mapping__c> getMappingDetails(
        String configurationDisplayName
    ) {
        System.debug('getMappingDetails: ' + configurationDisplayName);

        try {
            if (String.isBlank(configurationDisplayName)) {
                return new List<CgInfinity__Data_Feed_Mapping__c>();
            }

            List<CgInfinity__Data_Feed_Mapping__c> mappingDetails = [
                SELECT CgInfinity__Mapping_Name__c,
                    CgInfinity__File_Column_Name__c,
                    CgInfinity__Field_to_update__c,
                    CgInfinity__Is_LookUp__c,
                    CgInfinity__Lookup_Object_Name__c,
                    CgInfinity__Lookup_Field__c,
                    CgInfinity__Lookup_Return_Field__c,
                    CgInfinity__Lookup_Filter_Criteria__c,
                    CgInfinity__Is_Unique_Key__c,
                    CgInfinity__Operation__c
                FROM CgInfinity__Data_Feed_Mapping__c
                WHERE CgInfinity__Configuration_Display_Name__c = :configurationDisplayName
                ORDER BY CreatedDate ASC, Id ASC
            ];

            System.debug('Mapping Details: ' + mappingDetails);
            return mappingDetails;

        } catch (Exception e) {
            System.debug(
                'Error in getMappingDetails: ' +
                e.getMessage() + ' Line: ' + e.getLineNumber()
            );
            throw new AuraHandledException(
                'Unable to retrieve mapping details: ' + e.getMessage()
            );
        }
    }

    // To add new columns in Existing mapping (tan)
    @AuraEnabled
    public static void appendNewMappingColumns(
        String wrapperJson,
        String configurationDisplayName
    ) {
        if (String.isBlank(wrapperJson)) {
            throw new AuraHandledException('Missing parameter: wrapperJson.');
        }

        if (String.isBlank(configurationDisplayName)) {
            throw new AuraHandledException('Missing parameter: configurationDisplayName.');
        }

        ConfigurationWrapper wrapper;
        try {
            wrapper = (ConfigurationWrapper) JSON.deserialize(wrapperJson, ConfigurationWrapper.class);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Deserialization error: ' + e.getMessage());
            throw new AuraHandledException('Invalid mapping JSON: ' + e.getMessage());
        }

        if (wrapper == null || wrapper.mapping == null) {
            throw new AuraHandledException('Mapping configuration or mapping rows are missing.');
        }

        List<CgInfinity__Data_Feed_Mapping__c> existingRecords = [
            SELECT CgInfinity__File_Column_Name__c
            FROM CgInfinity__Data_Feed_Mapping__c
            WHERE CgInfinity__Configuration_Display_Name__c = :configurationDisplayName
        ];

        Set<String> existingHeaders = new Set<String>();
        for (CgInfinity__Data_Feed_Mapping__c record : existingRecords) {
            if (String.isNotBlank(record.CgInfinity__File_Column_Name__c)) {
                existingHeaders.add(record.CgInfinity__File_Column_Name__c.trim().toLowerCase());
            }
        }

        List<CgInfinity__Data_Feed_Mapping__c> recordsToInsert = new List<CgInfinity__Data_Feed_Mapping__c>();

        for (ConfigurationMapping mapping : wrapper.mapping) {
            if (String.isBlank(mapping.csvFieldName)) continue;

            String headerKey = mapping.csvFieldName.trim().toLowerCase();

            // Never insert a column that already exists.
            if (existingHeaders.contains(headerKey)) continue;

            if (String.isBlank(mapping.selectedField)) {
                throw new AuraHandledException('Select a Salesforce field for column: ' + mapping.csvFieldName);
            }

            CgInfinity__Data_Feed_Mapping__c record = new CgInfinity__Data_Feed_Mapping__c();
            record.CgInfinity__Mapping_Name__c = wrapper.mappingName;
            record.CgInfinity__Operation__c = wrapper.operationType;
            record.CgInfinity__File_Name__c = wrapper.fileName;
            record.CgInfinity__SObject_API_Name__c = wrapper.objectName;
            record.CgInfinity__File_Column_Name__c = mapping.csvFieldName;
            record.CgInfinity__Field_to_update__c = mapping.selectedField;
            record.CgInfinity__Is_Lookup__c = mapping.isLookup;
            record.CgInfinity__Lookup_Filter_Criteria__c = mapping.whereClause;

            if (mapping.isLookup) {
                record.CgInfinity__Lookup_Object_Name__c = mapping.lookupObject;
                record.CgInfinity__Lookup_Field__c = mapping.selectedLookupFields;
                record.CgInfinity__Lookup_Return_Field__c = mapping.returnField;
            }

            record.CgInfinity__Is_Unique_Key__c = mapping.isUniqueKey;

            recordsToInsert.add(record);
            existingHeaders.add(headerKey);
        }

        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }

    public class ConfigurationWrapper{
        @AuraEnabled public String objectName {get; set;}
        @AuraEnabled public String operationType {get; set;}
        @AuraEnabled public String fileName {get; set;}
        @AuraEnabled public String mappingName {get; set;}
        @AuraEnabled public List<ConfigurationMapping> mapping {get; set;}
    }

    public class ConfigurationMapping {
        @AuraEnabled public String csvFieldName {get; set;}
        @AuraEnabled public String selectedField {get; set;}
        @AuraEnabled public Boolean isLookup {get; set;}
        @AuraEnabled public String selectedLookupFields {get; set;}
        @AuraEnabled public String lookupObject {get; set;}
        @AuraEnabled public String whereClause {get; set;}
        @AuraEnabled public Boolean isUniqueKey {get; set;}
        @AuraEnabled public String targetObject {get; set;}
        @AuraEnabled public String matchField {get; set;}
        @AuraEnabled public String returnField {get; set;}
    }
}