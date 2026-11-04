public with sharing class DeleteUndeleteController {

    public class OperationResult {
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer failureCount { get; set; }
        @AuraEnabled public List<String> messages { get; set; }
        @AuraEnabled public String jobId { get; set; }

        public OperationResult() {
            totalRecords = 0;
            successCount = 0;
            failureCount = 0;
            messages = new List<String>();
            jobId = null;
        }
    }

    private static String generateJobId() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    }

    private static CgInfinity__Delete_Undelete_Record__c createLog(
        String recordId,
        String operation,
        String objectApiName,
        String jobId,
        String status,
        String errorMessage
    ) {
        return new CgInfinity__Delete_Undelete_Record__c(
            CgInfinity__Record_ID__c = recordId,
            CgInfinity__Operation__c = operation,
            CgInfinity__Target_Object__c = objectApiName,
            CgInfinity__Job_Id__c = jobId,
            CgInfinity__Status__c = status,
            CgInfinity__Error_Message__c = errorMessage,
            CgInfinity__Processed_Date__c = System.now(),
            CgInfinity__User__c = UserInfo.getUserId()
        );
    }

    private static Schema.SObjectType getObjectType(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Object API name is required.');
        }

        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName.trim());

        if (objectType == null) {
            throw new AuraHandledException(
                'Invalid Salesforce object: ' + objectApiName
            );
        }

        return objectType;
    }

    @AuraEnabled
    public static OperationResult deleteRecords(
        String objectApiName,
        List<String> recordIds
    ) {
        OperationResult result = new OperationResult();
        List<CgInfinity__Delete_Undelete_Record__c> logsToInsert =
            new List<CgInfinity__Delete_Undelete_Record__c>();

        Schema.SObjectType objectType = getObjectType(objectApiName);

        if (!objectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(
                'You do not have permission to delete records of ' +
                objectApiName + '.'
            );
        }

        result.jobId = generateJobId();
        result.totalRecords = recordIds == null ? 0 : recordIds.size();

        if (recordIds == null || recordIds.isEmpty()) {
            result.messages.add('No record IDs were provided.');
            return result;
        }

        List<Id> validIds = new List<Id>();
        List<Integer> validRowIndexes = new List<Integer>();

        for (Integer i = 0; i < recordIds.size(); i++) {
            String rawId = recordIds[i];
            String status = 'Failed';
            String errorMessage;
            Id parsedId;

            if (String.isBlank(rawId)) {
                errorMessage = 'Record ID is blank.';
            } else {
                try {
                    parsedId = Id.valueOf(rawId.trim());

                    if (parsedId.getSObjectType() != objectType) {
                        errorMessage =
                            'ID belongs to a different object: ' + rawId;
                        parsedId = null;
                    }
                } catch (Exception e) {
                    errorMessage = 'Invalid Salesforce ID: ' + rawId;
                }
            }

            if (parsedId == null) {
                logsToInsert.add(
                    createLog(
                        rawId,
                        'Delete',
                        objectApiName,
                        result.jobId,
                        status,
                        errorMessage
                    )
                );

                result.failureCount++;
                result.messages.add(errorMessage);
            } else {
                validIds.add(parsedId);
                validRowIndexes.add(i);
            }
        }

        if (!validIds.isEmpty()) {
            List<SObject> recordsToDelete = new List<SObject>();

            for (Id recordId : validIds) {
                SObject record = objectType.newSObject();
                record.put('Id', recordId);
                recordsToDelete.add(record);
            }

            Database.DeleteResult[] deleteResults =
                Database.delete(recordsToDelete, false);

            for (Integer i = 0; i < deleteResults.size(); i++) {
                Id recordId = validIds[i];

                if (deleteResults[i].isSuccess()) {
                    result.successCount++;

                    logsToInsert.add(
                        createLog(
                            String.valueOf(recordId),
                            'Delete',
                            objectApiName,
                            result.jobId,
                            'Success',
                            null
                        )
                    );

                    result.messages.add(
                        'Deleted successfully: ' + recordId
                    );
                } else {
                    String errorMessage = '';

                    for (Database.Error err : deleteResults[i].getErrors()) {
                        if (errorMessage != '') {
                            errorMessage += '; ';
                        }
                        errorMessage += err.getMessage();
                    }

                    result.failureCount++;

                    logsToInsert.add(
                        createLog(
                            String.valueOf(recordId),
                            'Delete',
                            objectApiName,
                            result.jobId,
                            'Failed',
                            errorMessage
                        )
                    );

                    result.messages.add(
                        'Delete failed for ' + recordId +
                        ': ' + errorMessage
                    );
                }
            }
        }

        if (!logsToInsert.isEmpty()) {
            Database.SaveResult[] logResults =
                Database.insert(logsToInsert, false);

            for (Integer i = 0; i < logResults.size(); i++) {
                if (!logResults[i].isSuccess()) {
                    for (Database.Error err : logResults[i].getErrors()) {
                        result.messages.add(
                            'Could not save operation log: ' +
                            err.getMessage()
                        );
                    }
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static OperationResult undeleteRecords(
        String objectApiName,
        List<String> recordIds
    ) {
        OperationResult result = new OperationResult();
        List<CgInfinity__Delete_Undelete_Record__c> logsToInsert =
            new List<CgInfinity__Delete_Undelete_Record__c>();

        Schema.SObjectType objectType = getObjectType(objectApiName);

        result.jobId = generateJobId();
        result.totalRecords = recordIds == null ? 0 : recordIds.size();

        if (recordIds == null || recordIds.isEmpty()) {
            result.messages.add('No record IDs were provided.');
            return result;
        }

        List<Id> validIds = new List<Id>();

        for (String rawId : recordIds) {
            Id parsedId = null;
            String errorMessage;

            if (String.isBlank(rawId)) {
                errorMessage = 'Record ID is blank.';
            } else {
                try {
                    parsedId = Id.valueOf(rawId.trim());

                    if (parsedId.getSObjectType() != objectType) {
                        errorMessage =
                            'ID belongs to a different object: ' + rawId;
                        parsedId = null;
                    }
                } catch (Exception e) {
                    errorMessage = 'Invalid Salesforce ID: ' + rawId;
                }
            }

            if (parsedId == null) {
                result.failureCount++;

                logsToInsert.add(
                    createLog(
                        rawId,
                        'Undelete',
                        objectApiName,
                        result.jobId,
                        'Failed',
                        errorMessage
                    )
                );

                result.messages.add(errorMessage);
            } else {
                validIds.add(parsedId);
            }
        }

        if (!validIds.isEmpty()) {
            Set<Id> idsToQuery = new Set<Id>();
            idsToQuery.addAll(validIds);

            String queryString =
                'SELECT Id, IsDeleted FROM ' +
                objectType.getDescribe().getName() +
                ' WHERE Id IN :idsToQuery ALL ROWS';

            List<SObject> queriedRecords = Database.query(queryString);

            Map<Id, SObject> recordsById = new Map<Id, SObject>();
            for (SObject record : queriedRecords) {
                recordsById.put((Id) record.get('Id'), record);
            }

            List<SObject> recordsToRestore = new List<SObject>();
            List<Id> restoreIds = new List<Id>();

            for (Id recordId : validIds) {
                SObject record = recordsById.get(recordId);

                if (record == null) {
                    result.failureCount++;

                    logsToInsert.add(
                        createLog(
                            String.valueOf(recordId),
                            'Undelete',
                            objectApiName,
                            result.jobId,
                            'Failed',
                            'Record not found or not available to restore.'
                        )
                    );

                    result.messages.add(
                        'Record not found or not available to restore: ' +
                        recordId
                    );
                } else if (!(Boolean) record.get('IsDeleted')) {
                    result.failureCount++;

                    logsToInsert.add(
                        createLog(
                            String.valueOf(recordId),
                            'Undelete',
                            objectApiName,
                            result.jobId,
                            'Skipped',
                            'Record is not deleted.'
                        )
                    );

                    result.messages.add(
                        'Skipped; record is not deleted: ' + recordId
                    );
                } else {
                    recordsToRestore.add(record);
                    restoreIds.add(recordId);
                }
            }

            if (!recordsToRestore.isEmpty()) {
                Database.UndeleteResult[] undeleteResults =
                    Database.undelete(recordsToRestore, false);

                for (Integer i = 0; i < undeleteResults.size(); i++) {
                    Id recordId = restoreIds[i];

                    if (undeleteResults[i].isSuccess()) {
                        result.successCount++;

                        logsToInsert.add(
                            createLog(
                                String.valueOf(recordId),
                                'Undelete',
                                objectApiName,
                                result.jobId,
                                'Success',
                                null
                            )
                        );

                        result.messages.add(
                            'Restored successfully: ' + recordId
                        );
                    } else {
                        String errorMessage = '';

                        for (Database.Error err :
                            undeleteResults[i].getErrors()) {
                            if (errorMessage != '') {
                                errorMessage += '; ';
                            }
                            errorMessage += err.getMessage();
                        }

                        result.failureCount++;

                        logsToInsert.add(
                            createLog(
                                String.valueOf(recordId),
                                'Undelete',
                                objectApiName,
                                result.jobId,
                                'Failed',
                                errorMessage
                            )
                        );

                        result.messages.add(
                            'Restore failed for ' + recordId +
                            ': ' + errorMessage
                        );
                    }
                }
            }
        }

        if (!logsToInsert.isEmpty()) {
            Database.SaveResult[] logResults =
                Database.insert(logsToInsert, false);

            for (Integer i = 0; i < logResults.size(); i++) {
                if (!logResults[i].isSuccess()) {
                    for (Database.Error err : logResults[i].getErrors()) {
                        result.messages.add(
                            'Could not save operation log: ' +
                            err.getMessage()
                        );
                    }
                }
            }
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<CgInfinity__Delete_Undelete_Record__c> getOperationLogs(
        String jobId,
        Integer pageSize,
        Integer offsetValue
    ) {
        if (String.isBlank(jobId)) {
            throw new AuraHandledException('Job ID is required.');
        }

        Integer safePageSize =
            pageSize == null ? 50 : Math.min(Math.max(pageSize, 1), 200);

        Integer safeOffset =
            offsetValue == null ? 0 : Math.max(offsetValue, 0);

        return [
            SELECT Id, Name,
                CgInfinity__Record_ID__c,
                CgInfinity__Operation__c,
                CgInfinity__Target_Object__c,
                CgInfinity__Status__c,
                CgInfinity__Error_Message__c,
                CgInfinity__Job_Id__c,
                CgInfinity__Processed_Date__c,
                CgInfinity__User__c
            FROM CgInfinity__Delete_Undelete_Record__c
            WHERE CgInfinity__Job_Id__c = :jobId
            ORDER BY CreatedDate DESC
            LIMIT :safePageSize
            OFFSET :safeOffset
        ];
    }
}