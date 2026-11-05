public class DataFeedJobTrackerTriggerHandler {

    public static void startBatchProcessor(
        List<CgInfinity__Data_Feed_Job_Tracker__c> newRecords,
        Map<Id, CgInfinity__Data_Feed_Job_Tracker__c> oldMap
    ) {
        for (CgInfinity__Data_Feed_Job_Tracker__c tracker : newRecords) {

            if (
                tracker.CgInfinity__Status__c == 'Upload Complete' &&
                oldMap.get(tracker.Id).CgInfinity__Status__c != 'Upload Complete'
            ) {
                CSVUploaderController.invokeProcessDataFeedBatch(
                    tracker.CgInfinity__File_Name__c,
                    tracker.CgInfinity__Operation_Type__c,
                    tracker.CgInfinity__Target_Object__c,
                    tracker.Id
                );
            }
        }
    }
}