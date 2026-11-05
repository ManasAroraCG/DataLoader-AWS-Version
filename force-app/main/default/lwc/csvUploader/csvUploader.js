import { LightningElement, track } from 'lwc';
import uploadToApex from '@salesforce/apex/CSVUploaderController.uploadToApex';
import updateDataFeedJobTrackerStatus from '@salesforce/apex/CSVUploaderController.updateDataFeedJobTrackerStatus';
import createDataFeedJobTracker from '@salesforce/apex/CSVUploaderController.createDataFeedJobTracker';
import getObjects from '@salesforce/apex/CSVDataController.getObjects';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPresignedUrl from '@salesforce/apex/CSVUploaderController.getPresignedUrl';
import getExistingMappings from '@salesforce/apex/CSVConfigurationMapping.getExistingMappings';
import getMappingDetails from '@salesforce/apex/CSVConfigurationMapping.getMappingDetails';
import deleteRecords from '@salesforce/apex/DeleteUndeleteController.deleteRecords';
import undeleteRecords from '@salesforce/apex/DeleteUndeleteController.undeleteRecords';
import LightningConfirm from 'lightning/confirm';
import CG_Infinity_Logo from '@salesforce/resourceUrl/CGInfinityLogo';

export default class csvUploader extends LightningElement {
    chunkSize = 200; 
    @track showMappingChoiceModal = false;
    @track csvFileContent = null;
    @track objectOptions = [];
    @track filteredObjectOptions = [];
    @track objectSearchTerm = '';
    objectInputHasFocus = false;
    @track operationOptions = [];
    @track selectedOperation = '';
    @track selectedObject = '';
    @track headersArray = [];
    @track showImportCard = true;
    @track showHeaderBlocks = false;
    @track showProgressBar=false;
    @track totalRecords=0;
    @track progressValue=0;
    @track processedRecords = 0;
    @track message;
    @track showObjectRecommendations = false;
    @track selectedIdColumn = 'Id';
    @track operationResult = null;
    @track operationResultMessages = [];
    
    // tan
    @track selectedUniqueKey = '';
    @track selectedMappingName = '';
    @track showFileNameDropdown = false; 
    @track existingMappings = [];
    @track selectedExistingMapping = '';
    @track existingMappingDetails = [];
    @track existingMappingMode = false;
    @track isMappingLoaded = false;
    @track existingPreviewRows = [];
    // for existing mapping data preview (tan)
    columns = [
        { label: 'File Name', fieldName: 'fileName', type: 'text' },
        { label: 'Csv Column', fieldName: 'columnName', type: 'text' },
        { label: 'SF Field', fieldName: 'salesforceField', type: 'text' },
        { label: 'Lookup Object', fieldName: 'lookupObject', type: 'text' },
        { label: 'Selected Lookup Mapping', fieldName: 'lookupMapping', type: 'text' },
        { label: 'Return Field', fieldName: 'returnField', type: 'text' }
    ];

    fileName = '';
    ObjectIsSelected=false;
    OperationIsSelected=false;
    jobTrackerId = null;
    CGInfinityLogo = CG_Infinity_Logo;
    get showUniqueKeyCombobox() {
        return this.selectedOperation === 'Update' && this.headersArray && this.headersArray.length > 0;
    }
    get isDeleteUndeleteOperation() {
        return ['Delete', 'Undelete'].includes(this.selectedOperation);
    }
 
    get uniqueKeyColumnOptions() {
        return (this.headersArray || []).map(h => ({ label: h, value: h }));
    }
 
    handleUniqueKeyChange(event) {
        this.selectedUniqueKey = event.detail.value;
    }
   
     get currentStep() {
         if (this.showImportCard) {
             return '1';
        } else if (this.showHeaderBlocks) {
            return '2';
        } else if (this.showProgressBar) {
            return '3';
        }
        return '1';
    }
    

    connectedCallback() {
        this.operationOptions = [
            { label: 'Insert', value: 'Insert' },
            { label: 'Update', value: 'Update' },
            { label: 'Upsert', value: 'Upsert' },
            { label: 'Delete', value: 'Delete' },
            { label: 'Undelete', value: 'Undelete' }
        ];
        getObjects()
            .then(data => {
                console.log('Objects loaded:', data);
                this.objectOptions = data.map(obj => ({ label: obj.label, value: obj.apiName }));
                this.filteredObjectOptions = this.objectOptions;
                console.log('objectOptions after map:', this.objectOptions);
            })
            .catch(error => {
                console.error('Error fetching objects:', error);
            });
    }

    handleObjectSearch(event) {
        const inputValue = event.target.value || '';
        const searchTerm = inputValue.toLowerCase().trim();
        
        this.objectSearchTerm = inputValue;
        console.log('Search term:', searchTerm, 'objectOptions length:', this.objectOptions.length);
        
        if (!searchTerm) {
            this.filteredObjectOptions = [];
            this.showObjectRecommendations = false;
            console.log('Empty search - hiding dropdown');
        } else {
            // Filter objects that contain the search term (case-insensitive)
            const filtered = this.objectOptions.filter(opt => 
                opt.label.toLowerCase().includes(searchTerm)
            );
            console.log('Filtered count:', filtered.length);
            this.filteredObjectOptions = [...filtered];
            // Always show recommendations dropdown when typing
            this.showObjectRecommendations = true;
            console.log('showObjectRecommendations SET TO TRUE');
        }
    }

    handleObjectRecommendationClick(event) {
        const value = event.currentTarget.dataset.value;
        const label = event.currentTarget.dataset.label;
        this.selectedObject = value;
        this.ObjectIsSelected = true;
        this.objectSearchTerm = label;
        this.showObjectRecommendations = false;
    }

    // loading existing mapping (tan)
    loadExistingMappings() {
        console.log('Loading existing mappings');
        console.log('Object:', this.selectedObject);
        console.log('Operation:', this.selectedOperation);

        getExistingMappings({
            objectName: this.selectedObject,
            operationType: this.selectedOperation
        })
            .then(result => {
                this.existingMappings = (result || []).map(name => ({
                    label: name,
                    value: name
                }));

                console.log('Existing mappings loaded:', this.existingMappings);

                if (this.existingMappings.length === 0) {
                    this.showToast(
                        'No Mappings Found',
                        'No existing mappings found for this object/operation combination.',
                        'info'
                    );
                }
            })
            .catch(error => {
                console.error('Error loading existing mappings:', error);
                this.showToast(
                    'Error',
                    error?.body?.message || 'Unable to load existing mappings',
                    'error'
                );
            });
    }

    // User update existing mapping (tan)
    handleExistingMappingChange(event) {
        console.log('Mapping selected:', event.detail.value);

        this.selectedExistingMapping = event.detail.value;
        this.isMappingLoaded = true;
        this.existingMappingMode = true;

        getMappingDetails({
            configurationDisplayName: this.selectedExistingMapping
        })
            .then(result => {
                console.log('Mapping details loaded:', JSON.stringify(result));

                this.existingMappingDetails = result || [];

                // Preview rows build karo
                this.existingPreviewRows = (result || []).map((row, index) => ({
                    id: row.Id || `existing-${index}`,
                    fileName: row.CgInfinity__Mapping_Name__c || '',
                    columnName: row.CgInfinity__File_Column_Name__c || '',
                    salesforceField: row.CgInfinity__Field_to_update__c || '',
                    isLookup: row.CgInfinity__Is_LookUp__c || false,
                    lookupObject: row.CgInfinity__Lookup_Object_Name__c || '',
                    lookupMapping: row.CgInfinity__Lookup_Field__c || '',
                    returnField: row.CgInfinity__Lookup_Return_Field__c || '',
                    isUniqueKey: row.CgInfinity__Is_Unique_Key__c || false
                }));

                console.log('Preview rows:', this.existingPreviewRows);
            })
            .catch(error => {
                console.error('Error loading mapping details:', error);
                this.showToast(
                    'Error',
                    error?.body?.message || 'Unable to load mapping details',
                    'error'
                );
            });
    }

    // OK-Button Moving forward from preview (tan)
    handleExistingMappingOk() {
        console.log('Existing Mapping OK clicked');

        this.isMappingLoaded = false;
        this.showFileNameDropdown = false;
        this.showHeaderBlocks = true;
    }

    // Cancel Button-Existing Mapping (tan)
    handleExistingMappingCancel() {
        console.log('Existing Mapping Cancel clicked');

        this.isMappingLoaded = false;
        this.existingPreviewRows = [];
        this.existingMappingDetails = [];
        this.selectedExistingMapping = '';
        this.existingMappingMode = false;
        this.showFileNameDropdown = true;
    }

    // Modal close - reset (tan)
    handleCloseMappingOptions() {
        console.log('Closing Mapping Options modal');

        this.showMappingChoiceModal = false;
        this.showImportCard = true;
        this.showHeaderBlocks = false;
        this.showProgressBar = false;

        this.showFileNameDropdown = false;
        this.isMappingLoaded = false;
        this.selectedExistingMapping = '';
        this.existingPreviewRows = [];
        this.existingMappingDetails = [];
        this.existingMappingMode = false;
    }


    // Recieving mapping name from csvFieldMapper
    handleMappingCreated(event) {
        const detail = event.detail;
        console.log('Mapping created event received:', detail);
        
        if (detail && detail.mappingName) {
            this.selectedMappingName = detail.mappingName;
            console.log('Selected Mapping Name:', this.selectedMappingName);
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Mapping Linked',
                message: 'Mapping "' + detail.mappingName + '" is now linked to this import.',
                variant: 'success'
            }));
        }
    }
 
    handleFileUpload(event) {
        const file = event.target.files[0];
        console.log('File uploaded:', file);
        let name = file.name;
        let ext = '';
        if (name.includes('.')) {
            ext = name.substring(name.lastIndexOf('.'));
            name = name.substring(0, name.lastIndexOf('.'));
        }
        name = name.replace(/_/g, '');
        this.fileName = name + ext;
        if (file) {
            const reader = new FileReader();
            reader.onload = async () => {
                this.csvFileContent = reader.result;
                const lines = this.csvFileContent.split('\n').filter(line => line.trim() !== ''); // Filter out blank rows
                let headers = lines[0].split(',');
                headers = headers.map(h => h.trim().replace(/\r|\n/g, ''));
                this.headersArray = headers;
                this.totalRecords = lines.length - 1; 
                console.log('Parsed headers:', this.headersArray);

                const idHeader = headers.find(
                    h => h.toLowerCase() === 'id'
                );
                this.selectedIdColumn = idHeader || null;

                if (
                    ['Delete', 'Undelete'].includes(this.selectedOperation) &&
                    !idHeader
                ) {
                    this.showToast(
                        'Missing Id Column',
                        'Your CSV must contain a column named Id.',
                        'error'
                    );
                }
            };
            reader.readAsText(file);
        }
    }
   
    handleObjectChange(event) {
        this.ObjectIsSelected=true;
        this.selectedObject = event.detail.value;
    }
        handleResetAll() {
        const mapper = this.template.querySelector('c-csv-field-mapper');
        if (mapper) {
            mapper.resetToHeaders(this.headersArray);
        }
    }
 
    handleOperationChange(event) {
    this.OperationIsSelected = true;
    this.selectedOperation = event.detail.value;

    this.operationResult = null;
    this.operationResultMessages = [];

    if (this.selectedOperation === 'Delete') {
        this.message = 'The CSV has been read. Records matching the supplied Salesforce IDs will be deleted.';
    } else if (this.selectedOperation === 'Undelete') {
        this.message = 'The CSV has been read. Deleted records matching the supplied Salesforce IDs will be restored.';
    } else if (this.selectedOperation === 'Insert') {
        this.message = 'The CSV Data has been read successfully, you will receive an Email notification once the Data is inserted.';
    } else {
        this.message = 'The CSV Data has been read successfully, you will receive an Email notification once the Data is updated.';
    }
}
 
    get showNextButton() {
        return (
            this.ObjectIsSelected &&
            this.OperationIsSelected &&
            this.fileName && this.fileName.length > 0
        );
    }
 
    async handleNextClick() {
    this.showFileNameDropdown = false;
    this.isMappingLoaded = false;
    this.selectedExistingMapping = '';
    this.existingMappingMode = false;
    this.existingPreviewRows = [];
    this.existingMappingDetails = [];

    // NEW: Delete/Undelete branch — mapping modal skip
    if (this.isDeleteUndeleteOperation) {
        if (!this.csvFileContent) {
            this.showToast('Error', 'Please upload a CSV file first.', 'error');
            return;
        }
        if (!this.selectedObject) {
            this.showToast('Error', 'Please select a Salesforce object.', 'error');
            return;
        }
        const hasIdHeader = this.headersArray.some(
            h => h.trim().toLowerCase() === 'id'
        );
        if (!hasIdHeader) {
            this.showToast(
                'Missing Id Column',
                'Your CSV must contain a column named Id.',
                'error'
            );
            return;
        }

        // Skip mapping screens, go straight to progress
        this.showImportCard = false;
        this.showHeaderBlocks = false;
        this.showMappingChoiceModal = false;
        this.showProgressBar = true;

        await this.processDeleteUndelete();
        return;
    }

    // Existing flow for Insert/Update/Upsert
    this.showImportCard = false;
    this.showHeaderBlocks = false;
    this.showMappingChoiceModal = true;
}
 
    handleUniqueKeyTypeSelect(event) {
        this.uniqueKeyType = event.target.value;
    }
 
    handleUniqueKeyTypeNext() {
        if (!this.uniqueKeyType) {
            return;
        }
        this.showUniqueKeyTypeModal = false;
        this.showImportCard = false;
        this.showHeaderBlocks = false;
        this.showMappingChoiceModal = true;
    }
 
    handleCreateNewMapping() {
        this.showMappingChoiceModal = false;
        this.showHeaderBlocks = true;
        this.showProgressBar = false;

        // clean state for create mapping flow (if mode changes then we need to tell field mapper that mode changes)
        this.existingMappingMode = false;
        this.selectedExistingMapping = '';
        this.existingMappingDetails = [];
        this.selectedMappingName = '';
    }
 
    handleUseExistingMapping() {
        console.log('Use Existing Mapping clicked');

        this.showMappingChoiceModal = false;
        this.showFileNameDropdown = true;

        // Clean state — re-entering clear the old state(tan)
        this.selectedExistingMapping = '';
        this.isMappingLoaded = false;
        this.existingPreviewRows = [];
        this.existingMappingDetails = [];
        this.existingMappingMode = false;
        this.selectedMappingName = ''; // Clear this so Modify button workds correctly

        this.loadExistingMappings();
    }
 
    parseCSV(csv) {
        const lines = csv.split('\n');
        const headers = lines[0].split(',');
        this.headersArray = headers;
        const jsonData = [];
 
        for (let i = 1; i < lines.length; i++) {
            const values = lines[i].split(',');
            if (values.length === headers.length) {
                const jsonLine = {};
                headers.forEach((header, index) => {
                    jsonLine[header.trim()] = values[index].trim();
                });
                jsonData.push(jsonLine);
            }
        }
        return jsonData;
    }
 
    async processCSV() {
        // Validate mapping before changing the screen
        if (!this.selectedMappingName && !this.selectedExistingMapping) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Mapping Required',
                    message: 'Please create a mapping before proceeding.',
                    variant: 'error'
                })
            );
            return;
        }
        this.showProgressBar = true;
        this.showHeaderBlocks = false;
        if (this.csvFileContent) {
            let name = this.fileName;
            let ext = '';
            if (name.includes('.')) {
                ext = name.substring(name.lastIndexOf('.'));
                name = name.substring(0, name.lastIndexOf('.'));
            }
            name = name.replace(/_/g, '');
            this.fileName = name + ext;
            console.log('File name:', this.fileName);
            console.log('Attempting to upload file to S3:', this.fileName);
            let uploadSuccess = false;
            try {
                console.log('Selected Operation:', this.selectedOperation);
                console.log('Selected Object:', this.selectedObject);
                // Preserve the original filename for the Job Tracker
                const baseFileName = this.fileName;

                // Create Job Tracker in Salesforce
                this.jobTrackerId = await createDataFeedJobTracker({
                    fileName: baseFileName,
                    operationType: this.selectedOperation,
                    targetObject: this.selectedObject,
                    selectedMappingName: this.selectedExistingMapping || this.selectedMappingName || ''  // tan
                });

                console.log('Created Job Tracker:', this.jobTrackerId);

                // Append operation and object to filename for S3
                this.fileName = baseFileName + '_' + this.selectedOperation + '_' + this.selectedObject;

                console.log('Updated Name:', this.fileName);

                // Request presigned URL
                const presignedUrl = await getPresignedUrl({
                    fileName: this.fileName,
                    jobTrackerId: this.jobTrackerId
                });
                console.log('Presigned URL:', presignedUrl);
                const uploadResponse = await fetch(presignedUrl, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'text/csv',
                        'x-amz-meta-job-tracker-id': this.jobTrackerId
                    },
                    body: new Blob([this.csvFileContent], { type: 'text/csv' })
                });
                if (uploadResponse.ok) {
                    console.log('File sent to S3 successfully:', this.fileName);
                    uploadSuccess = true;
                } else {
                    console.error('Error uploading file to S3:', uploadResponse.statusText);
                }
            } catch (error) {
                console.error('Error uploading file to S3:', error);
            }
            if (!uploadSuccess) {
                this.showProgressBar = false;

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Upload Failed',
                        message: 'The CSV could not be uploaded to S3. Please try again.',
                        variant: 'error'
                    })
                );

                return;
            }
            //   const jsonData = this.parseCSV(this.csvFileContent); // Parse CSV to JSON
            // if (!jsonData) {
            //     // Error already shown, stop processing
            //     console.log('CSV parsing failed. Stopping process.');
            //     this.showProgressBar = false;
            //     return;
            // }
            // try {
            //     await this.sendDataInChunks(jsonData, this.fileName); // Wait for all chunks to be sent
            //     // Invoke the ProcessDataFeed batch class
            //     await this.invokeBatchClass();
            // } catch (error) {
            //     console.error('Error during processing:', error);
            // }
        } else {
            console.error('No file uploaded. Please upload a CSV file before clicking Next.');
        }
    
    }

    // processing stage selection (tan)
    async handleProcessNext() {
        // Existing mapping mode then processCSV
        // New mapping mode then also processCSV
        // API mode? then processAPI
        if (this.selectedImportType === 'API') {
            await this.processAPI();
        } else {
            await this.processCSV();
        }
    }

    
    previousPage() {
        this.showHeaderBlocks = false;
        this.showImportCard = true;
        this.showProgressBar = false;
    }

    async processDeleteUndelete() {
    this.operationResult = null;
    this.operationResultMessages = [];
    this.processedRecords = 0;
    this.progressValue = 0;

    try {
        if (this.selectedOperation === 'Delete') {
            const confirmed = await LightningConfirm.open({
                label: 'Confirm Delete',
                message: 'Are you sure you want to delete the records identified by this CSV? This action may be difficult to reverse.',
                theme: 'warning'
            });
            if (!confirmed) {
                this.showProgressBar = false;
                this.showImportCard = true;
                return;
            }
        }

        const jsonData = this.parseCSV(this.csvFileContent);
        if (!jsonData.length) {
            throw new Error('No valid CSV data rows were found.');
        }

        // Find Id header (case-insensitive, strip BOM)
        const idHeader = Object.keys(jsonData[0] || {}).find(
            header => header
                .replace(/^\uFEFF/, '')
                .replace(/^"|"$/g, '')
                .trim()
                .toLowerCase() === 'id'
        );
        if (!idHeader) {
            throw new Error('No Id column was found. Please verify the first row of your CSV.');
        }

        this.selectedIdColumn = idHeader;

        const recordIds = jsonData
            .map(row => String(row[idHeader] ?? '').trim())
            .filter(id => id.length > 0);

        if (!recordIds.length) {
            throw new Error(`The "${idHeader}" column does not contain any record IDs.`);
        }

        this.totalRecords = recordIds.length;
        this.message = `${this.selectedOperation} operation is in progress...`;

        let result;
        if (this.selectedOperation === 'Delete') {
            result = await deleteRecords({
                objectApiName: this.selectedObject,
                recordIds: recordIds
            });
        } else {
            result = await undeleteRecords({
                objectApiName: this.selectedObject,
                recordIds: recordIds
            });
        }

        this.operationResult = result;
        this.operationResultMessages = (result.messages || []).map(
            (message, index) => ({ id: `result-${index}`, message })
        );

        this.processedRecords = result.totalRecords;
        this.progressValue = 100;

        this.message =
            `${this.selectedOperation} finished. ` +
            `Successful: ${result.successCount}, ` +
            `Failed: ${result.failureCount}.`;

        this.dispatchEvent(
            new ShowToastEvent({
                title: result.failureCount > 0
                    ? 'Operation completed with errors'
                    : 'Operation completed',
                message: this.message,
                variant: result.failureCount > 0 ? 'warning' : 'success'
            })
        );
    } catch (error) {
        this.message =
            error?.body?.message ||
            error?.message ||
            'The operation failed.';

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Operation failed',
                message: this.message,
                variant: 'error'
            })
        );
    }
}

    goToUploadPage() {
        this.jobTrackerId = null;
        this.showProgressBar = false;
        this.showImportCard = true;
        this.showHeaderBlocks = false;
        this.progressValue = 0;
        this.processedRecords = 0;
        this.fileName = '';
        this.csvFileContent = null;
        this.headersArray = [];
        this.selectedObject = '';
        this.selectedOperation = '';
        this.ObjectIsSelected = false;
        this.OperationIsSelected = false;
        this.selectedUniqueKey = '';
        this.objectSearchTerm = '';
        this.selectedMappingName = '';

        // resets for existing mapping
        this.showFileNameDropdown = false;
        this.isMappingLoaded = false;
        this.selectedExistingMapping = '';
        this.existingPreviewRows = [];
        this.existingMappingDetails = [];
        this.existingMappingMode = false;
        this.selectedIdColumn = 'Id';
        this.operationResult = null;
        this.operationResultMessages = [];
    }
 
    async sendDataInChunks(jsonData, fileName) {
        for (let i = 0; i < jsonData.length; i += this.chunkSize) {
            const chunk = jsonData.slice(i, i + this.chunkSize);
            
            const jsonStringList = chunk.map(record => JSON.stringify(record));
            console.log('json:',jsonStringList);
            try {
                // Send the chunk to Apex
                await uploadToApex({ jsonDataList: jsonStringList, fileName: fileName });
                this.processedRecords += chunk.length; // Update processed records
                this.progressValue = Math.floor((this.processedRecords / this.totalRecords) * 100); // Update progress bar
            } catch (error) {
                console.error('Error sending data to Apex:', error);
            }
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message:this.message,
                variant: 'success',
            })
        );
        console.log('All data sent successfully!');
    }
 
    async invokeBatchClass() {
        try {
           
            // Call an Apex method to invoke the batch class
            //await invokeProcessDataFeedBatch({fileName: this.fileName, operationType: this.selectedOperation, targetObject: this.selectedObject}); // Replace with the actual Apex method to invoke the batch
            await updateDataFeedJobTrackerStatus({status:'Upload Complete', fileName:this.fileName, operationType:this.selectedOperation,targetObject:this.selectedObject});
        } catch (error) {
            console.error('Error invoking batch class:', error);
            throw error;
        }
    }
 
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

}