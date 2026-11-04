public without sharing class CSVUploaderController {
    @AuraEnabled
    public static void uploadToApex(List<String> jsonDataList, String fileName) {

        System.debug('jsonDataList'+jsonDataList);
        
        List<CgInfinity__Data_Feed_Record__c> records = new List<CgInfinity__Data_Feed_Record__c>();
    
        for (String jsonString : jsonDataList) {
            CgInfinity__Data_Feed_Record__c obj = new CgInfinity__Data_Feed_Record__c();
            obj.CgInfinity__Data_Feed_Record_JSON__c = jsonString;
            obj.CgInfinity__File_Name__c = fileName;
            records.add(obj);
        }
    
        Database.insert(records);
    } 

    @AuraEnabled
    public static void updateDataFeedJobTrackerStatus(
        Id jobTrackerId,
        String status
    ) {
        try {
            CgInfinity__Data_Feed_Job_Tracker__c tracker =
                new CgInfinity__Data_Feed_Job_Tracker__c(
                    Id = jobTrackerId,
                    CgInfinity__Status__c = status
                );

            update tracker;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Error updating Job Tracker: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static void invokeProcessDataFeedBatch(
        String fileName,
        String operationType,
        String targetObject,
        Id jobTrackerId
    ){
        
        // String mappingName = null;

        // // fetching mapping name from job tracker (tan)
        // if (jobTrackerId != null) {
        //     List<CgInfinity__Data_Feed_Job_Tracker__c> trackers = [
        //         SELECT Id, CgInfinity__Selected_Mapping_Name__c
        //         FROM CgInfinity__Data_Feed_Job_Tracker__c
        //         WHERE Id = :jobTrackerId
        //         LIMIT 1
        //     ];

        //     if (!trackers.isEmpty() && 
        //         String.isNotBlank(trackers[0].CgInfinity__Selected_Mapping_Name__c)) {
        //         mappingName = trackers[0].CgInfinity__Selected_Mapping_Name__c;
        //         System.debug('Mapping name from tracker: ' + mappingName);
        //     }
        // }

        Database.executeBatch(
            new ProcessDataFeed(fileName, operationType, targetObject, jobTrackerId),
            200
        );
    }

    @AuraEnabled
    public static String getPresignedUrl(String fileName, Id jobTrackerId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_API/getPresignedUrl');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize( new Map<String, Object>{'fileName' => fileName, 'jobTrackerId' => jobTrackerId}));
            HttpResponse res = (new Http()).send(req);

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException(
                    'AWS API Error: ' + res.getStatusCode() + ' - ' + res.getBody()
                );
            }

            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug(result);
            if (result.containsKey('presignedUrl')) 
            {
                String url = (String) result.get('presignedUrl');
                System.debug(url);
                return url;
            }
            throw new AuraHandledException('Presigned URL not found in response');
        } catch (AuraHandledException e) {
                throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error getting presigned URL: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static Id createDataFeedJobTracker(
        String fileName,
        String operationType,
        String targetObject,
        String selectedMappingName
    ) {
        try {
            if (String.isBlank(selectedMappingName)) {
                throw new AuraHandledException(
                    'Please select a mapping before starting the import.'
                );
            }

            CgInfinity__Data_Feed_Job_Tracker__c tracker =
                new CgInfinity__Data_Feed_Job_Tracker__c();

            tracker.CgInfinity__File_Name__c = fileName;
            tracker.CgInfinity__Operation_Type__c = operationType;
            tracker.CgInfinity__Target_Object__c = targetObject;
            tracker.CgInfinity__Selected_Mapping_Name__c = selectedMappingName;
            tracker.CgInfinity__Status__c = 'Ready for Processing';

            insert tracker;

            return tracker.Id;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Error creating Job Tracker: ' + e.getMessage()
            );
        }
    }
    
}