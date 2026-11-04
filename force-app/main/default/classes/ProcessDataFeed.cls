public class ProcessDataFeed implements Database.Batchable<SObject> {
    private String fileToBeProcessed = '';
    private String operationType = '';
    private String targetObj = '';
    private Id jobTrackerId;
    private String selectedMappingName;

    Map<String,String> fieldColumnMapping = new Map<String,String>();
    Map<String,String> lookupColumnMapping = new Map<String,String>();
    List<String> lookupQueries = new List<String>();
    List<CgInfinity__Data_Feed_Mapping__c> lookupMappings =
        new List<CgInfinity__Data_Feed_Mapping__c>();

    public ProcessDataFeed(
        String fileName,
        String operation,
        String targetObject,
        Id jobTrackerId
    ) {
        if (jobTrackerId == null) {
            throw new IllegalArgumentException('Job Tracker ID is required.');
        }

        this.jobTrackerId = jobTrackerId;

        CgInfinity__Data_Feed_Job_Tracker__c tracker = [
            SELECT Id,
                   CgInfinity__File_Name__c,
                   CgInfinity__Operation_Type__c,
                   CgInfinity__Target_Object__c,
                   CgInfinity__Selected_Mapping_Name__c
            FROM CgInfinity__Data_Feed_Job_Tracker__c
            WHERE Id = :jobTrackerId
            LIMIT 1
        ];

        fileToBeProcessed = tracker.CgInfinity__File_Name__c;
        operationType = tracker.CgInfinity__Operation_Type__c;
        targetObj = tracker.CgInfinity__Target_Object__c;
        selectedMappingName = tracker.CgInfinity__Selected_Mapping_Name__c;

        if (String.isNotBlank(fileName) && fileName != fileToBeProcessed) {
            throw new IllegalArgumentException(
                'File name does not match the supplied Job Tracker.'
            );
        }
        if (String.isNotBlank(operation) && operation != operationType) {
            throw new IllegalArgumentException(
                'Operation does not match the supplied Job Tracker.'
            );
        }
        if (String.isNotBlank(targetObject) && targetObject != targetObj) {
            throw new IllegalArgumentException(
                'Target object does not match the supplied Job Tracker.'
            );
        }

        List<CgInfinity__Data_Feed_Mapping__c> mappings;

        if (String.isNotBlank(selectedMappingName)) {
            mappings = [
                SELECT CgInfinity__File_Name__c,
                       CgInfinity__File_Column_Name__c,
                       CgInfinity__SObject_API_Name__c,
                       CgInfinity__Field_to_update__c,
                       CgInfinity__Lookup_Filter_Criteria__c,
                       CgInfinity__Lookup_Object_Name__c,
                       CgInfinity__Lookup_Field__c,
                       CgInfinity__Lookup_Return_Field__c,
                       CgInfinity__Operation__c,
                       CgInfinity__Is_Lookup__c,
                       Id, Name
                FROM CgInfinity__Data_Feed_Mapping__c
                WHERE CgInfinity__Configuration_Display_Name__c = :selectedMappingName
                AND CgInfinity__Operation__c = :operationType
                AND CgInfinity__SObject_API_Name__c = :targetObj
                AND CgInfinity__Is_Lookup__c = false
            ];

            lookupMappings = [
                SELECT CgInfinity__File_Name__c,
                       CgInfinity__File_Column_Name__c,
                       CgInfinity__SObject_API_Name__c,
                       CgInfinity__Field_to_update__c,
                       CgInfinity__Lookup_Filter_Criteria__c,
                       CgInfinity__Lookup_Object_Name__c,
                       CgInfinity__Lookup_Field__c,
                       CgInfinity__Lookup_Return_Field__c,
                       CgInfinity__Operation__c,
                       CgInfinity__Is_Lookup__c,
                       Id, Name
                FROM CgInfinity__Data_Feed_Mapping__c
                WHERE CgInfinity__Configuration_Display_Name__c = :selectedMappingName
                AND CgInfinity__Operation__c = :operationType
                AND CgInfinity__SObject_API_Name__c = :targetObj
                AND CgInfinity__Is_Lookup__c = true
            ];
        } else {
            // Legacy fallback for trackers without a selected mapping name.
            mappings = [
                SELECT CgInfinity__File_Name__c,
                       CgInfinity__File_Column_Name__c,
                       CgInfinity__SObject_API_Name__c,
                       CgInfinity__Field_to_update__c,
                       CgInfinity__Lookup_Filter_Criteria__c,
                       CgInfinity__Lookup_Object_Name__c,
                       CgInfinity__Lookup_Field__c,
                       CgInfinity__Lookup_Return_Field__c,
                       CgInfinity__Operation__c,
                       CgInfinity__Is_Lookup__c,
                       Id, Name
                FROM CgInfinity__Data_Feed_Mapping__c
                WHERE CgInfinity__File_Name__c = :fileToBeProcessed
                AND CgInfinity__Operation__c = :operationType
                AND CgInfinity__SObject_API_Name__c = :targetObj
                AND CgInfinity__Is_Lookup__c = false
            ];

            lookupMappings = [
                SELECT CgInfinity__File_Name__c,
                       CgInfinity__File_Column_Name__c,
                       CgInfinity__SObject_API_Name__c,
                       CgInfinity__Field_to_update__c,
                       CgInfinity__Lookup_Filter_Criteria__c,
                       CgInfinity__Lookup_Object_Name__c,
                       CgInfinity__Lookup_Field__c,
                       CgInfinity__Lookup_Return_Field__c,
                       CgInfinity__Operation__c,
                       CgInfinity__Is_Lookup__c,
                       Id, Name
                FROM CgInfinity__Data_Feed_Mapping__c
                WHERE CgInfinity__File_Name__c = :fileToBeProcessed
                AND CgInfinity__Operation__c = :operationType
                AND CgInfinity__SObject_API_Name__c = :targetObj
                AND CgInfinity__Is_Lookup__c = true
            ];
        }

        if (mappings.isEmpty() && lookupMappings.isEmpty()) {
            throw new IllegalArgumentException(
                'No mapping records found for the selected configuration: ' +
                selectedMappingName
            );
        }

        for (CgInfinity__Data_Feed_Mapping__c mapping : mappings) {
            fieldColumnMapping.put(
                mapping.CgInfinity__File_Column_Name__c,
                mapping.CgInfinity__Field_to_update__c
            );
        }

        List<CgInfinity__Data_Feed_Mapping__c> validLookupMappings =
            new List<CgInfinity__Data_Feed_Mapping__c>();

        for (CgInfinity__Data_Feed_Mapping__c mapping : lookupMappings) {
            Boolean hasValidLookup =
                String.isNotBlank(mapping.CgInfinity__Lookup_Object_Name__c) &&
                String.isNotBlank(mapping.CgInfinity__Lookup_Field__c) &&
                String.isNotBlank(mapping.CgInfinity__Lookup_Return_Field__c);

            if (hasValidLookup) {
                validLookupMappings.add(mapping);
                lookupColumnMapping.put(
                    mapping.CgInfinity__File_Column_Name__c,
                    mapping.CgInfinity__Field_to_update__c
                );
            } else {
                fieldColumnMapping.put(
                    mapping.CgInfinity__File_Column_Name__c,
                    mapping.CgInfinity__Field_to_update__c
                );
            }
        }

        lookupMappings = validLookupMappings;

        System.debug('Job Tracker ID: ' + jobTrackerId);
        System.debug('Selected Mapping Name: ' + selectedMappingName);
        System.debug('Field mappings: ' + mappings);
        System.debug('Lookup mappings: ' + lookupMappings);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                   CgInfinity__File_Name__c,
                   CgInfinity__Error_Message__c,
                   CgInfinity__Data_Feed_Record_JSON__c,
                   CgInfinity__Is_Failed__c,
                   CgInfinity__Is_Processed__c,
                   CgInfinity__Data_Feed_Job_Tracker__c
            FROM CgInfinity__Data_Feed_Record__c
            WHERE CgInfinity__Is_Processed__c = false
            AND CgInfinity__Data_Feed_Job_Tracker__c = :jobTrackerId
            ORDER BY CreatedDate ASC
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<CgInfinity__Data_Feed_Record__c> scope
    ) {
        List<SObject> records = new List<SObject>();
        List<Map<String,Object>> dataFeedRecords =
            new List<Map<String,Object>>();
        Map<String,Set<Object>> lookupRecordsMap =
            new Map<String,Set<Object>>();

        List<CgInfinity__Data_Feed_Mapping__c> uniqueKeyMappings =
            new List<CgInfinity__Data_Feed_Mapping__c>();
        List<String> targetCsvCols = new List<String>();
        List<String> targetSfFields = new List<String>();

        if (operationType == 'Update') {
            if (String.isNotBlank(selectedMappingName)) {
                uniqueKeyMappings = [
                    SELECT CgInfinity__File_Column_Name__c,
                           CgInfinity__Field_to_update__c,
                           CgInfinity__Is_Lookup__c,
                           CgInfinity__Lookup_Field__c
                    FROM CgInfinity__Data_Feed_Mapping__c
                    WHERE CgInfinity__Configuration_Display_Name__c = :selectedMappingName
                    AND CgInfinity__Operation__c = :operationType
                    AND CgInfinity__SObject_API_Name__c = :targetObj
                    AND CgInfinity__Field_to_update__c = 'Id'
                ];
            } else {
                uniqueKeyMappings = [
                    SELECT CgInfinity__File_Column_Name__c,
                           CgInfinity__Field_to_update__c,
                           CgInfinity__Is_Lookup__c,
                           CgInfinity__Lookup_Field__c
                    FROM CgInfinity__Data_Feed_Mapping__c
                    WHERE CgInfinity__File_Name__c = :fileToBeProcessed
                    AND CgInfinity__Operation__c = :operationType
                    AND CgInfinity__SObject_API_Name__c = :targetObj
                    AND CgInfinity__Field_to_update__c = 'Id'
                ];
            }

            for (CgInfinity__Data_Feed_Mapping__c m : uniqueKeyMappings) {
                if (m.CgInfinity__Is_Lookup__c &&
                    m.CgInfinity__Lookup_Field__c != null &&
                    m.CgInfinity__Lookup_Field__c.contains(',')) {
                    continue;
                }

                targetCsvCols.add(m.CgInfinity__File_Column_Name__c);

                if (m.CgInfinity__Is_Lookup__c == true &&
                    String.valueOf(m.CgInfinity__Field_to_update__c).toLowerCase() == 'id') {
                    targetSfFields.add(m.CgInfinity__Lookup_Field__c);
                } else {
                    targetSfFields.add(m.CgInfinity__Field_to_update__c);
                }
            }
        } else if (operationType == 'Upsert') {
            if (String.isNotBlank(selectedMappingName)) {
                uniqueKeyMappings = [
                    SELECT CgInfinity__File_Column_Name__c,
                           CgInfinity__Field_to_update__c
                    FROM CgInfinity__Data_Feed_Mapping__c
                    WHERE CgInfinity__Configuration_Display_Name__c = :selectedMappingName
                    AND CgInfinity__Operation__c = :operationType
                    AND CgInfinity__SObject_API_Name__c = :targetObj
                    AND CgInfinity__Is_Unique_Key__c = true
                ];
            } else {
                uniqueKeyMappings = [
                    SELECT CgInfinity__File_Column_Name__c,
                           CgInfinity__Field_to_update__c
                    FROM CgInfinity__Data_Feed_Mapping__c
                    WHERE CgInfinity__File_Name__c = :fileToBeProcessed
                    AND CgInfinity__Operation__c = :operationType
                    AND CgInfinity__SObject_API_Name__c = :targetObj
                    AND CgInfinity__Is_Unique_Key__c = true
                ];
            }

            for (CgInfinity__Data_Feed_Mapping__c m : uniqueKeyMappings) {
                targetCsvCols.add(m.CgInfinity__File_Column_Name__c);
                targetSfFields.add(m.CgInfinity__Field_to_update__c);
            }

            System.debug('targetCsvCols: ' + targetCsvCols);
            System.debug('targetSfFields: ' + targetSfFields);
        }

        for (CgInfinity__Data_Feed_Record__c d : scope) {
            Map<String,Object> dataFeedRecord =
                (Map<String,Object>)JSON.deserializeUntyped(
                    d.CgInfinity__Data_Feed_Record_JSON__c
                );
            dataFeedRecords.add(dataFeedRecord);
        }

        Map<String,Map<String,Object>> fieldValuesMap =
            new Map<String,Map<String,Object>>();

        if (operationType == 'Update' && !targetCsvCols.isEmpty()) {
            for (Map<String,Object> rec : dataFeedRecords) {
                String key = '';
                for (String col : targetCsvCols) {
                    key += String.valueOf(rec.get(col)).trim();
                }
                fieldValuesMap.put(key, rec);
            }
        }

        Map<String,Id> existingRecordMap = new Map<String,Id>();

        if ((operationType == 'Update' || operationType == 'Upsert') &&
            !targetSfFields.isEmpty()) {

            String soql = 'SELECT Id';
            for (String f : targetSfFields) {
                soql += ', ' + f;
            }

            soql += ' FROM ' + targetObj + ' WHERE ';
            List<String> whereClauses = new List<String>();

            for (Integer i = 0; i < targetSfFields.size(); i++) {
                String f = targetSfFields[i];
                Set<String> values = new Set<String>();

                for (Map<String,Object> rec : dataFeedRecords) {
                    values.add(String.valueOf(rec.get(targetCsvCols[i])).trim());
                }

                String inClause = '';
                for (String v : values) {
                    inClause += '\'' + String.escapeSingleQuotes(v) + '\',';
                }

                if (inClause.endsWith(',')) {
                    inClause = inClause.substring(0, inClause.length() - 1);
                }

                whereClauses.add(f + ' IN (' + inClause + ')');
            }

            soql += String.join(whereClauses, ' AND ');
            List<SObject> existingRecords = Database.query(soql);

            for (SObject s : existingRecords) {
                String key = '';
                for (String f : targetSfFields) {
                    key += String.valueOf(s.get(f)).trim();
                }
                existingRecordMap.put(key, (Id)s.get('Id'));
            }
        }

        System.debug('existingRecordMap: ' + existingRecordMap);
                for (Map<String,Object> mp : dataFeedRecords) {
            for (CgInfinity__Data_Feed_Mapping__c dfm : lookupMappings) {
                if (dfm.CgInfinity__File_Column_Name__c.contains(',')) {
                    List<String> multipleLookups =
                        dfm.CgInfinity__File_Column_Name__c.split(',');

                    for (String s : multipleLookups) {
                        if (mp.get(s) != null) {
                            if (!lookupRecordsMap.containsKey(s) ||
                                lookupRecordsMap.get(s).isEmpty()) {
                                Set<Object> lookupValues = new Set<Object>();
                                lookupValues.add('\'' + mp.get(s) + '\'');
                                lookupRecordsMap.put(s, lookupValues);
                            } else {
                                Set<Object> lookupValues = lookupRecordsMap.get(s);
                                lookupValues.add('\'' + mp.get(s) + '\'');
                                lookupRecordsMap.put(s, lookupValues);
                            }
                        }
                    }
                } else {
                    if (mp.get(dfm.CgInfinity__File_Column_Name__c) != null) {
                        if (!lookupRecordsMap.containsKey(
                            dfm.CgInfinity__File_Column_Name__c
                        ) || lookupRecordsMap.get(
                            dfm.CgInfinity__File_Column_Name__c
                        ).isEmpty()) {
                            Set<Object> lookupValues = new Set<Object>();
                            lookupValues.add(
                                '\'' + mp.get(dfm.CgInfinity__File_Column_Name__c) + '\''
                            );
                            lookupRecordsMap.put(
                                dfm.CgInfinity__File_Column_Name__c,
                                lookupValues
                            );
                        } else {
                            Set<Object> lookupValues = lookupRecordsMap.get(
                                dfm.CgInfinity__File_Column_Name__c
                            );
                            lookupValues.add(
                                '\'' + mp.get(dfm.CgInfinity__File_Column_Name__c) + '\''
                            );
                            lookupRecordsMap.put(
                                dfm.CgInfinity__File_Column_Name__c,
                                lookupValues
                            );
                        }
                    }
                }
            }
        }

        Map<String,Map<String,String>> lookupResultsMap =
            new Map<String,Map<String,String>>();

        for (CgInfinity__Data_Feed_Mapping__c mapping : lookupMappings) {
            String lookupQuery;

            if (mapping.CgInfinity__File_Column_Name__c.contains(',')) {
                List<String> multipleLookups =
                    mapping.CgInfinity__File_Column_Name__c.split(',');
                List<String> multipleLookupFields =
                    mapping.CgInfinity__Lookup_Field__c.split(',');

                lookupQuery =
                    'SELECT ' + mapping.CgInfinity__Lookup_Field__c + ',' +
                    mapping.CgInfinity__Lookup_Return_Field__c +
                    ' FROM ' + mapping.CgInfinity__Lookup_Object_Name__c +
                    ' WHERE ';

                for (Integer k = 0; k < multipleLookups.size(); k++) {
                    String s = multipleLookups[k];
                    Set<Object> tempObject = lookupRecordsMap.get(s);
                    List<String> tempList = new List<String>();

                    if (tempObject != null) {
                        for (Object o : tempObject) {
                            tempList.add(String.valueOf(o));
                        }
                    }

                    String inClause = '';
                    for (Integer i = 0; i < tempList.size(); i++) {
                        inClause += String.escapeSingleQuotes(tempList[i]);

                        if (i < tempList.size() - 1) {
                            inClause += ',';
                        }

                        inClause = inClause.replace('\\', '');
                    }

                    if (k < multipleLookups.size() - 1) {
                        lookupQuery +=
                            multipleLookupFields[k] +
                            ' IN (' + inClause + ') AND ';
                    } else {
                        lookupQuery +=
                            multipleLookupFields[k] +
                            ' IN (' + inClause + ')';
                    }
                }

                if (String.isNotBlank(
                    mapping.CgInfinity__Lookup_Filter_Criteria__c
                )) {
                    lookupQuery +=
                        ' AND ' + mapping.CgInfinity__Lookup_Filter_Criteria__c;
                }
            } else {
                Set<Object> tempObject = lookupRecordsMap.get(
                    mapping.CgInfinity__File_Column_Name__c
                );

                List<String> tempList = new List<String>();

                if (tempObject != null) {
                    for (Object o : tempObject) {
                        tempList.add(String.valueOf(o));
                    }
                }

                String inClause = '';
                for (Integer i = 0; i < tempList.size(); i++) {
                    inClause += String.escapeSingleQuotes(tempList[i]);

                    if (i < tempList.size() - 1) {
                        inClause += ',';
                    }

                    inClause = inClause.replace('\\', '');
                }

                lookupQuery =
                    'SELECT ' + mapping.CgInfinity__Lookup_Field__c + ',' +
                    mapping.CgInfinity__Lookup_Return_Field__c +
                    ' FROM ' + mapping.CgInfinity__Lookup_Object_Name__c +
                    ' WHERE ' + mapping.CgInfinity__Lookup_Field__c +
                    ' IN (' + inClause + ')';

                if (String.isNotBlank(
                    mapping.CgInfinity__Lookup_Filter_Criteria__c
                )) {
                    lookupQuery +=
                        ' AND ' + mapping.CgInfinity__Lookup_Filter_Criteria__c;
                }
            }

            System.debug('Final lookup query: ' + lookupQuery);
            List<SObject> lookupRecords = Database.query(lookupQuery);

            for (SObject s : lookupRecords) {
                if (mapping.CgInfinity__File_Column_Name__c.contains(',')) {
                    List<String> fileColumns =
                        mapping.CgInfinity__File_Column_Name__c.split(',');
                    List<String> fields =
                        mapping.CgInfinity__Lookup_Field__c.split(',');

                    String tempFileColumnName = '';
                    String tempValues = '';

                    for (Integer i = 0; i < fileColumns.size(); i++) {
                        tempValues += (String)s.get(fields[i]);

                        if (i < fileColumns.size() - 1) {
                            tempFileColumnName += fileColumns[i] + ',';
                        } else {
                            tempFileColumnName += fileColumns[i];
                        }
                    }

                    if (!lookupResultsMap.containsKey(tempFileColumnName)) {
                        Map<String,String> tempMap = new Map<String,String>();
                        tempMap.put(
                            tempValues,
                            (String)s.get(mapping.CgInfinity__Lookup_Return_Field__c)
                        );
                        lookupResultsMap.put(tempFileColumnName, tempMap);
                    } else {
                        Map<String,String> tempMap =
                            lookupResultsMap.get(tempFileColumnName);
                        tempMap.put(
                            tempValues,
                            (String)s.get(mapping.CgInfinity__Lookup_Return_Field__c)
                        );
                        lookupResultsMap.put(tempFileColumnName, tempMap);
                    }
                } else {
                    String fileColumnName =
                        mapping.CgInfinity__File_Column_Name__c;

                    if (!lookupResultsMap.containsKey(fileColumnName)) {
                        Map<String,String> tempMap = new Map<String,String>();
                        tempMap.put(
                            (String)s.get(mapping.CgInfinity__Lookup_Field__c),
                            (String)s.get(mapping.CgInfinity__Lookup_Return_Field__c)
                        );
                        lookupResultsMap.put(fileColumnName, tempMap);
                    } else {
                        Map<String,String> tempMap =
                            lookupResultsMap.get(fileColumnName);
                        tempMap.put(
                            (String)s.get(mapping.CgInfinity__Lookup_Field__c),
                            (String)s.get(mapping.CgInfinity__Lookup_Return_Field__c)
                        );
                        lookupResultsMap.put(fileColumnName, tempMap);
                    }
                }
            }
        }

        for (Integer idx = 0; idx < scope.size(); idx++) {
            CgInfinity__Data_Feed_Record__c d = scope[idx];

            try {
                Map<String,Object> dataFeedRecord =
                    (Map<String,Object>)JSON.deserializeUntyped(
                        d.CgInfinity__Data_Feed_Record_JSON__c
                    );

                SObject targetRecord =
                    Schema.getGlobalDescribe().get(targetObj).newSObject();

                if ((operationType == 'Update' || operationType == 'Upsert') &&
                    !targetCsvCols.isEmpty()) {

                    String rowKey = '';

                    for (String col : targetCsvCols) {
                        rowKey += String.valueOf(dataFeedRecord.get(col)).trim();
                    }

                    if (existingRecordMap.containsKey(rowKey)) {
                        targetRecord.put('Id', existingRecordMap.get(rowKey));
                    }

                    System.debug('rowKey: ' + rowKey);
                    System.debug('targetRecord: ' + targetRecord);
                }

                Schema.SObjectType objType =
                    Schema.getGlobalDescribe().get(targetObj);
                Map<String,Schema.SObjectField> fieldMap =
                    objType.getDescribe().fields.getMap();

                for (String key : dataFeedRecord.keySet()) {
                    if (fieldColumnMapping.get(key) != null) {
                        String sfField = fieldColumnMapping.get(key);
                        Object value = dataFeedRecord.get(key);

                        if (fieldMap.containsKey(sfField)) {
                            Schema.DescribeFieldResult fdesc =
                                fieldMap.get(sfField).getDescribe();
                            Schema.DisplayType dtype = fdesc.getType();

                            if (value != null && String.valueOf(value) != '') {
                                try {
                                    switch on dtype {
                                        when CURRENCY, DOUBLE {
                                            value = Decimal.valueOf(String.valueOf(value));
                                        }
                                        when INTEGER {
                                            value = Integer.valueOf(String.valueOf(value));
                                        }
                                        when DATE {
                                            value = Date.valueOf(String.valueOf(value));
                                        }
                                        when DATETIME {
                                            value = Datetime.valueOf(String.valueOf(value));
                                        }
                                        when BOOLEAN {
                                            value = (
                                                String.valueOf(value).toLowerCase() == 'true'
                                            );
                                        }
                                        when PERCENT {
                                            value = Decimal.valueOf(String.valueOf(value));
                                        }
                                        when TIME {
                                            String timeStr = String.valueOf(value);
                                            value = (Time)JSON.deserialize(
                                                '"' + timeStr + '"',
                                                Time.class
                                            );
                                        }
                                        when ID, REFERENCE, STRING, EMAIL, URL,
                                             PHONE, TEXTAREA, ENCRYPTEDSTRING,
                                             PICKLIST, MULTIPICKLIST {
                                            value = String.valueOf(value);
                                        }
                                        when BASE64 {
                                            value = EncodingUtil.base64Decode(
                                                String.valueOf(value)
                                            );
                                        }
                                        when ADDRESS, LOCATION {
                                            value = String.valueOf(value);
                                        }
                                        when COMBOBOX {
                                            value = String.valueOf(value);
                                        }
                                        when ANYTYPE {
                                            // Keep original value.
                                        }
                                        when else {
                                            value = String.valueOf(value);
                                        }
                                    }
                                } catch (Exception convEx) {
                                    System.debug(
                                        'Type conversion failed for field ' +
                                        sfField + ': ' + convEx.getMessage()
                                    );
                                    value = null;
                                }
                            } else {
                                value = null;
                            }
                        }

                        targetRecord.put(sfField, value);
                        System.debug('targetRecord: ' + targetRecord);
                    }
                }

                for (CgInfinity__Data_Feed_Mapping__c mapConfig : lookupMappings) {
                    String csvKey = mapConfig.CgInfinity__File_Column_Name__c;
                    List<String> cols = csvKey.split(',');
                    String csvCompositeValue = '';
                    Boolean missingData = false;

                    for (String c : cols) {
                        Object val = dataFeedRecord.get(c.trim());

                        if (val == null) {
                            missingData = true;
                            break;
                        }

                        csvCompositeValue += String.valueOf(val);
                    }

                    if (!missingData) {
                        Map<String,String> resMap = lookupResultsMap.get(csvKey);

                        if (resMap != null &&
                            resMap.containsKey(csvCompositeValue)) {
                            targetRecord.put(
                                mapConfig.CgInfinity__Field_to_update__c,
                                resMap.get(csvCompositeValue)
                            );
                        }
                    }
                }

                if (operationType == 'Update' &&
                    targetRecord.get('Id') == null) {
                    throw new ProcessDataFeedException(
                        'No existing record found for update. Key lookup failed.'
                    );
                }

                records.add(targetRecord);

            } catch (Exception e) {
                d.CgInfinity__Is_Processed__c = true;
                d.CgInfinity__Is_Failed__c = true;
                d.CgInfinity__Error_Message__c =
                    (operationType == 'Update'
                        ? 'Error preparing record for update: '
                        : 'Error preparing record for insert: ') +
                    e.getMessage() + ' at line ' + e.getLineNumber();

                records.add(null);
            }
        }

                System.debug('records: ' + records);

        Map<Id,String> errorMap = new Map<Id,String>();
        List<SObject> recordsToProcess = new List<SObject>();
        Map<Integer,Integer> originalIndexMap =
            new Map<Integer,Integer>();

        Map<Id,SObject> uniqueRecordsMap = new Map<Id,SObject>();

        for (Integer i = 0; i < records.size(); i++) {
            SObject rec = records[i];

            if (rec != null) {
                Id recId = (Id)rec.get('Id');

                if (recId != null) {
                    if (!uniqueRecordsMap.containsKey(recId)) {
                        uniqueRecordsMap.put(recId, rec);
                        originalIndexMap.put(recordsToProcess.size(), i);
                        recordsToProcess.add(rec);
                    }
                } else {
                    originalIndexMap.put(recordsToProcess.size(), i);
                    recordsToProcess.add(rec);
                }
            }
        }

        if (!recordsToProcess.isEmpty()) {
            List<Database.SaveResult> saveResults;
            List<Database.UpsertResult> upsertResults;

            if (operationType == 'Upsert') {
                upsertResults = Database.upsert(recordsToProcess, false);
                System.debug('upsertResults: ' + upsertResults);
            } else if (operationType == 'Update') {
                saveResults = Database.update(recordsToProcess, false);
            } else {
                saveResults = Database.insert(recordsToProcess, false);
            }

            Integer resultSize = (operationType == 'Upsert')
                ? upsertResults.size()
                : saveResults.size();

            for (Integer i = 0; i < resultSize; i++) {
                Boolean isSuccess;
                List<Database.Error> errors;

                if (operationType == 'Upsert') {
                    isSuccess = upsertResults[i].isSuccess();
                    errors = upsertResults[i].getErrors();
                } else {
                    isSuccess = saveResults[i].isSuccess();
                    errors = saveResults[i].getErrors();
                }

                if (!isSuccess) {
                    Integer originalScopeIndex = originalIndexMap.get(i);
                    Id failedRecordId = scope[originalScopeIndex].Id;
                    String errorMessage = '';

                    for (Database.Error err : errors) {
                        errorMessage +=
                            'Error: ' + err.getStatusCode() +
                            ' - ' + err.getMessage();

                        if (err.getFields() != null &&
                            !err.getFields().isEmpty()) {
                            errorMessage +=
                                ' (Fields: ' +
                                String.join(err.getFields(), ', ') +
                                '). ';
                        } else {
                            errorMessage += '. ';
                        }
                    }

                    errorMap.put(failedRecordId, errorMessage.trim());
                }
            }
        }

        for (CgInfinity__Data_Feed_Record__c dfr : scope) {
            dfr.CgInfinity__Is_Processed__c = true;

            if (errorMap.containsKey(dfr.Id)) {
                dfr.CgInfinity__Error_Message__c = errorMap.get(dfr.Id);
                dfr.CgInfinity__Is_Failed__c = true;
            } else if (dfr.CgInfinity__Error_Message__c == null) {
                dfr.CgInfinity__Error_Message__c = null;
            }
        }

        update scope;
    }

    public void finish(Database.BatchableContext context) {
        List<CgInfinity__Data_Feed_Job_Tracker__c> trackers = [
            SELECT Id,
                   CgInfinity__File_Name__c,
                   CgInfinity__Operation_Type__c,
                   CgInfinity__Target_Object__c,
                   CgInfinity__Status__c,
                   CgInfinity__Selected_Mapping_Name__c,
                   CreatedBy.Email
            FROM CgInfinity__Data_Feed_Job_Tracker__c
            WHERE Id = :jobTrackerId
            LIMIT 1
        ];

        if (trackers.isEmpty()) {
            System.debug('Job Tracker not found: ' + jobTrackerId);
            return;
        }

        CgInfinity__Data_Feed_Job_Tracker__c jobTracker = trackers[0];

        if (jobTracker.CgInfinity__Status__c == 'Upload Complete') {
            jobTracker.CgInfinity__Status__c = 'Completed';
            update jobTracker;

            Integer totalRecords = [
                SELECT COUNT()
                FROM CgInfinity__Data_Feed_Record__c
                WHERE CgInfinity__Data_Feed_Job_Tracker__c = :jobTrackerId
            ];

            Integer processedRecords = [
                SELECT COUNT()
                FROM CgInfinity__Data_Feed_Record__c
                WHERE CgInfinity__Data_Feed_Job_Tracker__c = :jobTrackerId
                AND CgInfinity__Is_Processed__c = true
            ];

            Integer failedRecords = 0;

            for (CgInfinity__Data_Feed_Record__c rec : [
                SELECT CgInfinity__Error_Message__c
                FROM CgInfinity__Data_Feed_Record__c
                WHERE CgInfinity__Data_Feed_Job_Tracker__c = :jobTrackerId
                AND CgInfinity__Is_Processed__c = true
            ]) {
                if (String.isNotBlank(rec.CgInfinity__Error_Message__c)) {
                    failedRecords++;
                }
            }

            try {
                List<String> toAddresses = new List<String>();

                if (jobTracker.CreatedBy != null &&
                    String.isNotBlank(jobTracker.CreatedBy.Email)) {
                    // Retains the existing recipient from your AWS version.
                    toAddresses.add('karansbisht7@gmail.com');
                }

                if (!toAddresses.isEmpty()) {
                    Messaging.SingleEmailMessage mail =
                        new Messaging.SingleEmailMessage();

                    mail.setToAddresses(toAddresses);

                    String subject =
                        'Data Feed Processing Completed: ' +
                        jobTracker.CgInfinity__File_Name__c;

                    String body =
                        'Dear Team,\n\n' +
                        'The data feed file "' +
                        jobTracker.CgInfinity__File_Name__c +
                        '" has finished processing.\n\n' +
                        'Operation: ' +
                        jobTracker.CgInfinity__Operation_Type__c + '\n' +
                        'Target Object: ' +
                        jobTracker.CgInfinity__Target_Object__c + '\n' +
                        'Selected Mapping: ' +
                        jobTracker.CgInfinity__Selected_Mapping_Name__c + '\n' +
                        'Total Records: ' + totalRecords + '\n' +
                        'Processed Records: ' + processedRecords + '\n' +
                        'Successful Records: ' +
                        (processedRecords - failedRecords) + '\n' +
                        'Failed Records: ' + failedRecords + '\n\n' +
                        'You can review the Data Feed Job Tracker records ' +
                        'and any error messages in Salesforce.\n\n' +
                        'Regards,\nYour Salesforce Data Importer';

                    mail.setSubject(subject);
                    mail.setPlainTextBody(body);

                    Messaging.sendEmail(
                        new Messaging.SingleEmailMessage[] { mail }
                    );
                }
            } catch (Exception e) {
                System.debug(
                    'Failed to send completion email: ' + e.getMessage()
                );
            }
        }
    }

    public class ProcessDataFeedException extends Exception {}
}