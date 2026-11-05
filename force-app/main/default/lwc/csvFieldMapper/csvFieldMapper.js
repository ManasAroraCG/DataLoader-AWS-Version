import { api, LightningElement, track } from 'lwc';
import getFields from '@salesforce/apex/CSVDataController.getFields';
import getLookupFields from '@salesforce/apex/LookupUtility.getLookupFieldsWithObjectName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createConfiguration from '@salesforce/apex/CSVConfigurationMapping.createConfiguration';
import mappingNameExists from '@salesforce/apex/CSVConfigurationMapping.mappingNameExists';
import appendNewMappingColumns from '@salesforce/apex/CSVConfigurationMapping.appendNewMappingColumns';

export default class CsvFieldMapper extends LightningElement {
    // Unique Key Section State
    @track selectedUniqueKeyColumns = [];
    @track createdUniqueKeyColumns = [];
    @track _uniqueKeyCreated = false;
    @track showCompositeMappingUI = false;
    @track uniqueIdentifierWhereClause = '';
    @api selectedObject = 'Opportunity'; // Default selected object
    @api selectedOperation = 'Insert'; // Default operation type
    @api fileName = 'migration.csv'; // Default operation type
    @track fieldOptions = [];
    @track selectedFields = [];
    @track lookupFields = [];
    @track selectedLookupField = '';
    @api csvHeaders = ['Id', 'Name', 'Email', 'Phone', 'Description']; // Example CSV fields
    @api availableObjects = [];
    @track selectedDropdownValues = [];
    @track csvHeaderOptions = []; // For composite mapping checkboxes
    @track uniqueKeyHeaderOptions = []; // For unique key selection checkboxes
    @track compositeHeaderOptions = []; // Separate tracking for composite column headers
    @track createdCompositeMappings = [];
    @track compositeMappingIdCounter = 0;
    @track compositeSections = [];
    @track activeCompositeSection = 0;
    @track searchFieldOptions = '';
    @track searchLookupObjectOptionsPerRow = {};
    @track searchTargetObjectOptions = {};
    @track searchCompositeTargetObjectOptions = {};
    @track searchCompositeDropdownOptions = {};
    @track configuration = {
        objectName: '',
        operationType: '',
        fileName: this.fileName,
        mapping: []
    };

    // ===== MAPPING NAME POPUP STATE =====
    @track showMappingPopup = false;
    @track mappingNameInput = '';
    @track mappingNameError = '';
    @track isSaving = false;

        // EXISTING MAPPING STATE
    @track isMappingModified = false;
    @api existingMappingMode = false;
    @api existingMappingDisplayName;
    @track hasHeaderDifferences = false;
    _existingMappingDetails = [];
    _isInitialized = false;

    @api
    get existingMappingDetails() {
        return this._existingMappingDetails;
    }

    set existingMappingDetails(value) {
        this._existingMappingDetails = Array.isArray(value) ? value : [];
        if (this._isInitialized && this._existingMappingDetails.length > 0) {
            this.populateExistingMapping();
        }
    }

    @api uniqueKeyType = '';
    @api
    resetToHeaders(headers) {
        this.createdCompositeMappings = [];
        this.compositeMappingIdCounter = 0;
        this.compositeSections = [];
        this.compositeHeaderOptions = [];
        this.csvHeaders = headers;
        this.lookupFields = [];
        this.selectedFields = [];
        this.selectedDropdownValues = [];
        this.uniqueIdentifierWhereClause = '';
        this.csvHeaderOptions = this.csvHeaders.map(item => ({
            label: item,
            value: item,
            isSelected: false
            }));
            this.createInitialCsvMapping();
        }
        
        // Descriptive information for UI
        compositeKeyDescription = 'A composite key combines multiple fields to uniquely identify records. For example: Name + Phone creates a unique identifier using both fields together.';
        mappingStepDescription = 'Match each CSV column to the corresponding Salesforce field. For lookup fields, select the fields that will identify related records.';
        
        @api getMappedCsvColumns() {
            return this.selectedDropdownValues.map(item => item.csvFieldName || item.keyField).filter(Boolean);
        }
    columns = [
        { label: 'Csv Column', fieldName: 'csvFieldName' },
        { label: 'SF Field', fieldName: 'selectedField' },
        { label: 'Lookup Object', fieldName: 'lookupObjectName' },
        { label: 'Selected Lookup Mapping', fieldName: 'lookupField1' },
        { label: 'Return Field', fieldName: 'returnField' }
    ];
 
    get showUniqueKeySection() {
        return  this.selectedOperation === 'Upsert';
    }
    get showUniqueKeyCombobox() {
        return this.selectedOperation === 'Upsert' && (this.csvHeaderOptions.length > 0 || this.compositeHeaderOptions.length > 0);
    }
    
   
    get uniqueKeyCreated() {
        return this.createdUniqueKeyColumns.length > 0;
    }
 
    get isCreateUniqueKeyDisabled() {
        return !this.selectedUniqueKeyColumns || this.selectedUniqueKeyColumns.length === 0;
    }
    
    // Helper to build dropdown configs for composite columns
    buildCompositeDropdowns(column) {
        if (!column || !column.value || !column.isComposite) return [];
        const parts = column.value.split(',').map(s => s.trim());
        return parts.map(part => ({
            label: part,
            valueProp: 'lookupField_' + part,
            value: column['lookupField_' + part] || '',
            options: column.lookupObjectOptions,
            name: part
        }));
    }

    // --- Cross-object, non-lookup mapping handlers ---
    // Handler for SINGLE (non-composite) non-lookup target object selection
    handleTargetObjectChange(event) {
        const keyField =
            (event.detail && event.detail.keyField) ||
            (event.currentTarget && event.currentTarget.dataset
                ? event.currentTarget.dataset.keyfield
                : '') ||
            (event.target && event.target.dataset
                ? event.target.dataset.keyfield
                : '');
        const value = event.detail.value;
        const idx = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (idx === -1) return;

        const item = { ...this.selectedDropdownValues[idx] };
        item.targetObject = value;
        item.matchField = '';
        item.returnField = '';
        item.targetObjectFields = [];
        this.selectedDropdownValues[idx] = item;
        this.selectedDropdownValues = [...this.selectedDropdownValues]; // Trigger reactivity

        if (value) {
            console.log('Fetching fields for single non-lookup object:', value);
            getFields({ objectName: value })
                .then(data => {
                    const fieldsArray = data.map(field => ({ label: field.label, value: field.apiName }));
                    this.selectedDropdownValues[idx] = {
                        ...this.selectedDropdownValues[idx],
                        targetObjectFields: fieldsArray
                    };
                    this.selectedDropdownValues = [...this.selectedDropdownValues];
                    console.log('Fetched target object fields for', value, ':', fieldsArray);
                })
                .catch((error) => {
                    console.error('Error fetching target object fields:', error);
                    this.selectedDropdownValues[idx] = {
                        ...this.selectedDropdownValues[idx],
                        targetObjectFields: []
                    };
                    this.selectedDropdownValues = [...this.selectedDropdownValues];
                });
        }
    }

    // Handler for COMPOSITE non-lookup target object selection
    handleCompositeTargetObjectChange(event) {
        const keyField =
            (event.detail && event.detail.keyField) ||
            (event.currentTarget && event.currentTarget.dataset
                ? event.currentTarget.dataset.keyfield
                : '') ||
            (event.target && event.target.dataset
                ? event.target.dataset.keyfield
                : '');
        const value = event.detail.value;
        const idx = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (idx === -1) return;

        const item = { ...this.selectedDropdownValues[idx] };
        console.log('handleCompositeTargetObjectChange - before update:', 'isComposite:', item.isComposite, 'keyField:', keyField);
        
        item.targetObject = value;
        item.compositeTargetObject = value;
        item.returnField = '';
        item.compositeTargetObjectFields = [];
        
        console.log('handleCompositeTargetObjectChange - after update:', 'isComposite:', item.isComposite);
        
        this.selectedDropdownValues[idx] = item;
        this.selectedDropdownValues = [...this.selectedDropdownValues]; // Trigger reactivity immediately

        if (value) {
            console.log('Fetching fields for composite non-lookup object:', value);
            getFields({ objectName: value })
                .then(data => {
                    const fieldsArray = data.map(field => ({ label: field.label, value: field.apiName }));
                    console.log('After fetch - idx:', idx, 'isComposite before:', this.selectedDropdownValues[idx].isComposite);
                    
                    this.selectedDropdownValues[idx] = {
                        ...this.selectedDropdownValues[idx],
                        compositeTargetObjectFields: fieldsArray
                    };
                    
                    console.log('After fetch - isComposite after:', this.selectedDropdownValues[idx].isComposite);
                    this.selectedDropdownValues = [...this.selectedDropdownValues];
                    console.log('Fetched composite target object fields for', value, ':', fieldsArray);
                })
                .catch((error) => {
                    console.error('Error fetching composite target object fields:', error);
                    this.selectedDropdownValues[idx] = {
                        ...this.selectedDropdownValues[idx],
                        compositeTargetObjectFields: []
                    };
                    this.selectedDropdownValues = [...this.selectedDropdownValues];
                });
        }
    }

    handleTargetObjectMatchFieldChange(event) {
        const keyField =
            (event.detail && event.detail.keyField) ||
            (event.currentTarget && event.currentTarget.dataset
                ? event.currentTarget.dataset.keyfield
                : '') ||
            (event.target && event.target.dataset
                ? event.target.dataset.keyfield
                : '');
        const value = event.detail.value;
        const idx = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (idx !== -1) {
            this.selectedDropdownValues[idx].matchField = value;
            this.selectedDropdownValues = [...this.selectedDropdownValues];
        }
    }
    handleTargetObjectReturnFieldChange(event) {
        const keyField =
            (event.detail && event.detail.keyField) ||
            (event.currentTarget && event.currentTarget.dataset
                ? event.currentTarget.dataset.keyfield
                : '') ||
            (event.target && event.target.dataset
                ? event.target.dataset.keyfield
                : '');
        const value = event.detail.value;
        const idx = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (idx !== -1) {
            this.selectedDropdownValues[idx].returnField = value;
            this.selectedDropdownValues = [...this.selectedDropdownValues];
        }

    }
    // Returns array of parts for a composite key (split by ',')
    getCompositeParts(columnValue) {
        if (!columnValue) return [];
        return columnValue.split(',').map(s => s.trim());
    }
    handleUniqueKeyCheckboxChange(event) {
        const value = event.target.dataset.value;
        const checked = event.target.checked;
        if (checked) {
            if (!this.selectedUniqueKeyColumns.includes(value)) {
                this.selectedUniqueKeyColumns = [...this.selectedUniqueKeyColumns, value];
            }
        } else {
            this.selectedUniqueKeyColumns = this.selectedUniqueKeyColumns.filter(col => col !== value);
        }

        this.uniqueKeyHeaderOptions = this.uniqueKeyHeaderOptions.map(opt => ({
            ...opt,
            isSelected: this.selectedUniqueKeyColumns.includes(opt.value)
        }));
        // Update dropdowns for unique key section
        this.updateUniqueKeyDropdowns();
    }
 
    handleCreateUniqueKey() {
        if (this.selectedUniqueKeyColumns.length === 0) {
            this.showToast('Error', 'Select at least one column.', 'error');
            return;
        }
        this.createdUniqueKeyColumns = [...this.selectedUniqueKeyColumns];
        this._uniqueKeyCreated = true;
        this.showToast('Success', 'Unique key defined.', 'success');
    }
 
    handleRemoveUniqueKey() {
        this.createdUniqueKeyColumns = [];
        this.selectedUniqueKeyColumns = [];
        this._uniqueKeyCreated = false;
        this.uniqueKeyHeaderOptions = this.uniqueKeyHeaderOptions.map(opt => ({
            ...opt,
            isSelected: false
        }));
    }
 
    // --- For Unique Key Section Dropdowns ---
    @track selectedCsvColumns = [];
    @track selectedSfFields = [];
    @track sfFieldOptions = [];
 
    // Sync selectedCsvColumns and sfFieldOptions when unique key columns change
    getSelectedKeyColumns() {
        // Use selectedUniqueKeyColumns for unique key section
        return this.selectedUniqueKeyColumns && this.selectedUniqueKeyColumns.length > 0
            ? this.selectedUniqueKeyColumns
            : this.csvHeaders;
    }
 
    // Called in connectedCallback and when unique key changes
    updateUniqueKeyDropdowns() {
        this.selectedCsvColumns = this.getSelectedKeyColumns();
        // Ensure selectedSfFields has same length
        if (!this.selectedSfFields || this.selectedSfFields.length !== this.selectedCsvColumns.length) {
            this.selectedSfFields = Array(this.selectedCsvColumns.length).fill('');
        }
        // Use fieldOptions for dropdown options
        this.sfFieldOptions = this.fieldOptions;
    }
 
    // Handler for dropdown change in unique key section
    handleSfFieldChange(event) {
        const idx = event.target.dataset.index;
        const value = event.detail.value;
        if (idx !== undefined) {
            this.selectedSfFields[idx] = value;
        }
    }
 
    connectedCallback() {
        // Initialize any data or state here if needed
        this.createInitialCsvMapping();  

        // Initialize composite mapping options from csvHeaders
        this.csvHeaderOptions = this.csvHeaders.map(item => ({
            label: item,
            value: item,
            isSelected: false
        }));
        this.uniqueKeyHeaderOptions = this.csvHeaders.map(item => ({
            label: item,
            value: item,
            isSelected: false
        }));
        // Get lookup fields for the selected object
        getFields({ objectName: this.selectedObject }).then(data => {
            this.fieldsWithLookupList = data.filter(field => field.isLookup).map(field => ({ label: field.label, apiName: field.apiName, isLookup: field.isLookup }));
            this.fieldOptions = data.map(field => ({ label: field.label, value: field.apiName }));   

            // Update dropdowns for unique key section
            this.updateUniqueKeyDropdowns();

            // Rebuild existing mappings now that salesforce fields are loaded.
            if(this._existingMappingDetails?.length){
                this.populateExistingMapping();
            }

        }).catch(error => {
            console.error('Error loading fields for object:', this.selectedObject, error);
            this.showToast('Error', 'Failed to load fields for ' + this.selectedObject + '. ' + (error.body ? error.body.message : error.message || ''), 'error');
        });

        this._isInitialized = true;
        if(this._existingMappingDetails.length>0) {
            this.populateExistingMapping();
        } else {
            this.createInitialCsvMapping();  // only create blank rows if NO existing mapping exists
        }

        // Initial update for unique key section
        this.updateUniqueKeyDropdowns();
    }
   
    handleShowCompositeMappingUI() {
        // Only add a new section if there are no sections, or the last one is mapped
        if (
            this.compositeSections.length === 0 ||
            this.compositeSections[this.compositeSections.length - 1].isMapped
        ) {
            this.compositeSections.push({
                id: this.compositeSections.length,
                selectedColumns: [],
                isMapped: false,
                isButtonDisabled: false,
                // For composite columns, add static property names for dropdowns
                name1: 'composite1',
                name2: 'composite2',
                lookupField1: '',
                lookupField2: '',
            });
        } else {
            this.showToast('Error', 'Please complete the current composite mapping before adding a new one.', 'error');
        }
    }
   
    handleFieldChange(event) {
        let keyField;
        let selectedValue;
        let isLookup = false;
 
        // Case A: structured child event
        // if (event && event.detail && event.detail.keyField) {
        //     const fieldDetails = event.detail;
        //     console.log('Received structured field change event:', fieldDetails);
        //     keyField = fieldDetails.keyField;
        //     console.log('keyField:', keyField);
        //     selectedValue = fieldDetails.selectedValue || fieldDetails.value || '';
        //     console.log('selectedValue:', selectedValue);
        //     isLookup = !!fieldDetails.isLookup;
        //     console.log('isLookup:', isLookup);
 
        //     const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        //     if (index !== -1) {
        //         if (isLookup) {
        //             this.selectedDropdownValues[index] = { ...this.selectedDropdownValues[index],
        //                 selectedField: selectedValue,
        //                 lookupObject: fieldDetails.lookupObjectName || '',
        //                 whereClause: fieldDetails.whereClause || '',
        //                 isLookup: true,
        //                 selectedLookupFields: fieldDetails.selectedLookupFieldValues || [],
        //                 extraCsvField: fieldDetails.extraCsvField || ''
        //             };
        //         } else {
        //             this.selectedDropdownValues[index] = { ...this.selectedDropdownValues[index],
        //                 selectedField: selectedValue,
        //                 isLookup: false,
        //                 lookupObject: "",
        //                 whereClause: "",
        //                 selectedLookupFields: [],
        //                 extraCsvField: ""
        //             };
        //         }
        //     }
        //     return;
        // }
 
        // if (event && event.detail && event.detail.value && event.target && event.target.name) {
        //     keyField = event.target.name;
        //     selectedValue = event.detail.value;
        //     // determine if value is a lookup field
        //     isLookup = !!(this.fieldsWithLookupList && this.fieldsWithLookupList.some(f => f.apiName === selectedValue));
        //     const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        //     if (index !== -1) {
        //         this.selectedDropdownValues[index] = {
        //             ...this.selectedDropdownValues[index],
        //             selectedField: selectedValue,
        //             isLookup: isLookup,
        //             lookupObject: isLookup ? (this.selectedDropdownValues[index].lookupObject || '') : '',
        //             selectedLookupFields: isLookup ? (this.selectedDropdownValues[index].selectedLookupFields || []) : [],
        //             extraCsvField: isLookup ? (this.selectedDropdownValues[index].extraCsvField || '') : ''
        //         };
        //     }
        //     return;
        // }
        // Case B: simple event from dropdown
        console.log('Received simple field change event:', event.detail, event.target);
        if (event && event.target && event.target.name) {
 
            keyField = event.target.name;
            selectedValue = event.target.value;
            const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
 
                if (index !== -1) {
 
                isLookup = !!(this.fieldsWithLookupList && this.fieldsWithLookupList.some(f => f.apiName === selectedValue));
                console.log("whereClause"+this.uniqueIdentifierWhereClause);
                  let returnField = this.selectedDropdownValues[index].returnField;
                if (
                    isLookup &&
                    selectedValue &&
                    typeof selectedValue === 'string' &&
                    selectedValue.trim().toLowerCase().endsWith('id')
                ) {
                    returnField = 'Id';
                }
                this.selectedDropdownValues[index] = {
                    ...this.selectedDropdownValues[index],
                    selectedField: selectedValue,
                    isLookup: isLookup,
                    whereClause: this.uniqueIdentifierWhereClause || '',
                    selectedLookupFields: isLookup ? (this.selectedDropdownValues[index].selectedLookupFields || []) : [],
                    returnField: returnField || ''
                };
               
                if(selectedValue === 'Id') {
                    // For Id field, set lookup object to selected object
                    this.selectedDropdownValues[index] = {
                        ...this.selectedDropdownValues[index],
                        lookupObjectApiName: this.selectedObject,
                        lookupObjectName: this.selectedObject,
                        lookupObjectOptions: this.fieldOptions,
                    };
                    this.selectedDropdownValues = [...this.selectedDropdownValues];
                    console.log('Set lookup object to selected object for Id field:', this.selectedObject);
                }
                else if (isLookup ) {
                    // Get the lookup field details
                    const lookupFieldObj = this.fieldsWithLookupList.find(f => f.apiName === selectedValue);
                   
                    if (lookupFieldObj) {
                        // Fetch the lookup fields and object information
                        getLookupFields({ parentObjectName: this.selectedObject, lookupFieldName: selectedValue })
                        .then(data => {
                            const lookupFieldOptions = data.fieldList.map(field => ({ label: field.label, value: field.apiName, isLookup: field.isLookup }));
                            console.log('Fetched lookup fields for', selectedValue, ':', lookupFieldOptions);
                            console.log('Lookup Object Name:', data.lookUpObjectName);
                           
                            // Get fields of the lookup object to populate lookup object options
                            return getFields({ objectName: data.lookUpObjectName }).then(lookupObjFields => {
                                const lookupObjFieldOptions = lookupObjFields.map(field => ({
                                    label: field.label,
                                    value: field.apiName
                                }));
                               
                                // Convert API name to display name (e.g., "OperatingHour" -> "Operating Hour")
                                const displayName = this.convertApiNameToDisplayName(data.lookUpObjectName);
                               
                                this.selectedDropdownValues[index] = {
                                    ...this.selectedDropdownValues[index],
                                    lookupObjectOptions: lookupObjFieldOptions,
                                    lookupObjectApiName: data.lookUpObjectName,
                                    lookupObjectName: displayName,
                                };
                                // force reactive update
                                this.selectedDropdownValues = [...this.selectedDropdownValues];
                                console.log('Updated lookup object:', displayName);
                                console.log('Updated lookup object options:', lookupObjFieldOptions);
                            });
                        })
                        .catch(error => {
                            console.error('Error fetching lookup object fields:', error);
                        });
                    }
                } else {
                    // clear any lookup-specific options when not a lookup
                    // BUT preserve isComposite flag if it was already set
                    const shouldPreserveComposite = this.selectedDropdownValues[index].isComposite === true;
                    this.selectedDropdownValues[index] = {
                        ...this.selectedDropdownValues[index],
                        lookupObjectOptions: [],
                        lookupObjectApiName: '',
                        lookupObjectName: '',
                        whereClause: '',
                        isComposite: shouldPreserveComposite, // Preserve if it's a composite
                        targetObject: '',
                        targetObjectFields: [],
                        compositeTargetObjectFields: [],
                        matchField: '',
                        returnField: ''
                    }
                    }
                    this.selectedDropdownValues = [...this.selectedDropdownValues];
                }
            }
        }
    
 
    // handleLookupObjectChange(event) {
    //     const keyField = event.target.name;
    //     const value = event.detail && event.detail.value ? event.detail.value : event.target.value;
    //     const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
    //     if (index !== -1) {
    //         this.selectedDropdownValues[index] = {
    //             ...this.selectedDropdownValues[index],
    //             lookupObjectApiName: value,
    //             lookupObjectName: this.convertApiNameToDisplayName(value) || value,
    //             lookupObjectOptions: [] // clear while loadin
    //         };
    //         this.selectedDropdownValues = [...this.selectedDropdownValues];
    //         getFields({ objectName: value })
    //             .then(fields => {
    //                 const options = fields.map(f => ({ label: f.label, value: f.apiName }));
    //                 this.selectedDropdownValues[index] = {
    //                     ...this.selectedDropdownValues[index],
    //                     lookupObjectOptions: options
    //                 };
    //                 this.selectedDropdownValues = [...this.selectedDropdownValues];
    //             })
    //             .catch(error => {
    //                 this.selectedDropdownValues[index] = {
    //                     ...this.selectedDropdownValues[index],
    //                     lookupObjectOptions: []
    //                 };
    //                 this.selectedDropdownValues = [...this.selectedDropdownValues];
    //                 console.error('Error fetching fields for lookup object:', error);
    //             });
    //     }
    // }
 
    // NEW HANDLER: For Use Lookup Checkbox
    handleLookupCheckboxChange(event) {
        const key = event.target.dataset.keyfield;
        const isLookup = event.target.checked;

        const index = this.selectedDropdownValues.findIndex(
            item => item.keyField === key
        );

        if (index === -1) {
            return;
        }

        const currentItem = this.selectedDropdownValues[index];
        const selectedValue = currentItem.selectedField;

        const isCompositeLookup =
            isLookup && currentItem.isComposite === true;

        // -----------------------------------------
        // COMPOSITE LOOKUP
        // -----------------------------------------
        if (isCompositeLookup) {

            this.selectedDropdownValues[index] = {
                ...currentItem,
                isLookup: true,
                isCompositeLookup: true,

                // User will select this manually
                lookupObjectApiName: '',
                lookupObjectName: '',
                lookupObjectOptions: [],
                lookupObjectFields: [],

                // Composite field selections
                selectedLookupFields: '',

                returnField: ''
            };

            this.selectedDropdownValues = [
                ...this.selectedDropdownValues
            ];

            // VERY IMPORTANT:
            // Do NOT execute normal lookup logic.
            return;
        }

        // -----------------------------------------
        // LOOKUP TURNED OFF
        // -----------------------------------------
        if (!isLookup) {

            this.selectedDropdownValues[index] = {
                ...currentItem,

                isLookup: false,
                isCompositeLookup: false,

                lookupObjectApiName: '',
                lookupObjectName: '',
                lookupObjectOptions: [],
                lookupObjectFields: [],

                lookupField1: '',
                selectedLookupFields: '',
                whereClause: '',
                returnField: ''
            };

            this.selectedDropdownValues = [
                ...this.selectedDropdownValues
            ];

            return;
        }

        // -----------------------------------------
        // NORMAL LOOKUP
        // -----------------------------------------

        this.selectedDropdownValues[index] = {
            ...currentItem,
            isLookup: true,
            isCompositeLookup: false
        };

        this.selectedDropdownValues = [
            ...this.selectedDropdownValues
        ];

        if (!selectedValue) {
            return;
        }

        if (selectedValue === 'Id') {

            this.selectedDropdownValues[index] = {
                ...this.selectedDropdownValues[index],
                lookupObjectApiName: this.selectedObject,
                lookupObjectName: this.selectedObject,
                lookupObjectOptions: this.fieldOptions
            };

            this.selectedDropdownValues = [
                ...this.selectedDropdownValues
            ];

            return;
        }

        const lookupFieldObj =
            this.fieldsWithLookupList &&
            this.fieldsWithLookupList.find(
                field => field.apiName === selectedValue
            );

        if (!lookupFieldObj) {
            console.log(
                'Selected field is not a lookup field:',
                selectedValue
            );
            return;
        }

        getLookupFields({
            parentObjectName: this.selectedObject,
            lookupFieldName: selectedValue
        })
            .then(data => {

                return getFields({
                    objectName: data.lookUpObjectName
                }).then(lookupObjFields => {

                    const lookupObjFieldOptions =
                        lookupObjFields.map(field => ({
                            label: field.label,
                            value: field.apiName
                        }));

                    this.selectedDropdownValues[index] = {
                        ...this.selectedDropdownValues[index],

                        lookupObjectApiName:
                            data.lookUpObjectName,

                        lookupObjectName:
                            this.convertApiNameToDisplayName(
                                data.lookUpObjectName
                            ),

                        lookupObjectOptions:
                            lookupObjFieldOptions
                    };

                    this.selectedDropdownValues = [
                        ...this.selectedDropdownValues
                    ];
                });
            })
            .catch(error => {
                console.error(
                    'Error fetching lookup object:',
                    error
                );
            });
    }
 
    handleLookupFieldSelection(event) {
        const partName = event.target.name; // Composite part name or field name
        const keyField = event.target.dataset.keyfield || event.target.name; // Get from data attribute or name
        const value = event.detail.value; // Selected value from combobox
       
        console.log('handleLookupFieldSelection - partName:', partName, 'keyField:', keyField, 'value:', value);
       
        // Find the selectedDropdownValues entry
        const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        console.log('Found index:', index, 'Total items:', this.selectedDropdownValues.length);
       
        if (index !== -1) {
            const currentItem = this.selectedDropdownValues[index];
            console.log('Current item isComposite:', currentItem.isComposite, 'value contains comma:', currentItem.value && currentItem.value.includes(','));
           
            // Check if this is a composite field (has multiple parts)
            if (currentItem.isComposite && currentItem.value && currentItem.value.includes(',')) {
                // Store value with dynamic property name for each composite part
                const propName = 'lookupField_' + partName;
                this.selectedDropdownValues[index] = {
                    ...this.selectedDropdownValues[index],
                    [propName]: value
                };
                console.log('Updated composite field:', propName, '=', value);
            } else {
                // For non-composite lookups, store in lookupField1
                this.selectedDropdownValues[index] = {
                    ...this.selectedDropdownValues[index],
                    lookupField1: value,
                    selectedLookupFields: value
                };
                console.log('Updated non-composite lookupField1:', value);
            }
            this.selectedDropdownValues = [...this.selectedDropdownValues];
            console.log('Updated item:', this.selectedDropdownValues[index]);
        } else {
            console.log('WARNING: Could not find item with keyField:', keyField);
            console.log('Available keyFields:', this.selectedDropdownValues.map(item => item.keyField));
        }
    }
 
    // NEW HANDLER: For Composite Lookup Search
    handleCompositeLookupFieldSearch(event) {
        const term = event.target.value || '';
        const keyField = event.target.dataset.keyfield;
        
        const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (index === -1) return;

        const currentItem = this.selectedDropdownValues[index];
        let searchTerm = term.toLowerCase().trim();
        
        // We need to update the dropdown options based on search
        this.selectedDropdownValues[index] = {
            ...currentItem,
            compositeLookupSearchTerm: term,
            showCompositeLookupRecommendations: searchTerm.length > 0,
            filteredCompositeLookupOptions: searchTerm.length > 0 ? 
                (currentItem.lookupObjectOptions || []).filter(opt => 
                    opt.label.toLowerCase().includes(searchTerm) || opt.value.toLowerCase().includes(searchTerm)
                ) : []
        };
        
        this.selectedDropdownValues = [...this.selectedDropdownValues];
    }

    // NEW HANDLER: For Composite Lookup Recommendation Click
    handleCompositeLookupFieldClick(event) {
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        const keyField = event.currentTarget.dataset.keyfield;
        const partName = event.currentTarget.dataset.partname;

        const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (index === -1) return;

        // Update the item with selected value
        const currentItem = this.selectedDropdownValues[index];
        const propName = 'lookupField_' + partName;
        
        this.selectedDropdownValues[index] = {
            ...currentItem,
            [propName]: selectedValue,
            compositeLookupSearchTerm: selectedLabel,
            showCompositeLookupRecommendations: false
        };

        this.selectedDropdownValues = [...this.selectedDropdownValues];
    }

    handleWhereClauseChange(event) {
        const keyField = event.target.name;
        const value = event.target.value;
        const index = this.selectedDropdownValues.findIndex(obj => obj.keyField === keyField);
        if (index !== -1) {
            this.selectedDropdownValues[index] = {
                ...this.selectedDropdownValues[index],
                whereClause: value
            };
            this.selectedDropdownValues = [...this.selectedDropdownValues];
        }
    }
 
    // Helper method to convert API name to display name
    // Example: "OperatingHour" -> "Operating Hour", "Account" -> "Account"
    convertApiNameToDisplayName(apiName) {
        if (!apiName) return '';
        // Insert space before uppercase letters (except the first one)
        return apiName.replace(/([A-Z])/g, ' $1').trim();
    }
 
    // Getter function to retrieve selected value for a specific header
    getSelectedValue(header) {
        return this.selectedValues[header] || '';
    }
   
     handleDeleteCompositeSection(event) {
        const sectionId = parseInt(event.currentTarget.dataset.sectionid, 10);
        // Remove the section
        this.compositeSections = this.compositeSections.filter(sec => sec.id !== sectionId);
        // Remove the mapping and composite header if it was mapped
        const mapping = this.createdCompositeMappings.find(m => m.id === sectionId);
        if (mapping) {
            const compositeKey = mapping.compositeKey;
            const uniqueKeyField = `${compositeKey}__COMPOSITE_${sectionId}`;
            this.selectedDropdownValues = this.selectedDropdownValues.filter(row => row.keyField !== uniqueKeyField);
            this.compositeHeaderOptions = this.compositeHeaderOptions.filter(opt => opt.value !== uniqueKeyField);
            this.csvHeaders = this.csvHeaders.filter(h => h !== compositeKey);
            this.createdCompositeMappings = this.createdCompositeMappings.filter(m => m.id !== sectionId);
        }
            // Re-index section ids to be sequential
            this.compositeSections = this.compositeSections.map((sec, idx) => ({ ...sec, id: idx }));
    }
    
    // ===== STEP 1: Button click -> popup kholo =====
createMapping() {
    // Pehle basic validation
    if (!this.selectedObject) {
        this.showToast('Error', 'Please select an object first.', 'error');
        return;
    }
    if (!this.selectedDropdownValues || this.selectedDropdownValues.length === 0) {
        this.showToast('Error', 'No mapping rows to save.', 'error');
        return;
    }

    // Popup kholo (mapping build abhi nahi karna — popup me Save dabane pe karenge)
    this.mappingNameInput = '';
    this.mappingNameError = '';
    this.isSaving = false;
    this.showMappingPopup = true;
}

// ===== STEP 2: Popup input handler =====
handleMappingNameChange(event) {
    this.mappingNameInput = event.target.value;
    this.mappingNameError = ''; // clear error as user types
}

// ===== STEP 3: Popup close =====
closeMappingPopup() {
    if (this.isSaving) return; // saving ke beech close mat karne do
    this.showMappingPopup = false;
    this.mappingNameInput = '';
    this.mappingNameError = '';
}

// ===== STEP 4: Popup me "Save" click =====
async handleSaveMappingName() {
    const name = (this.mappingNameInput || '').trim();

    // Blank check
    if (!name) {
        this.mappingNameError = 'Mapping name is required.';
        return;
    }

    this.isSaving = true;
    this.mappingNameError = '';

    try {
        // ===== Duplicate check =====
        const alreadyExists = await mappingNameExists({ mappingName: name });
        if (alreadyExists) {
            this.mappingNameError = 'This mapping name already exists. Please choose another.';
            this.isSaving = false;
            return;
        }

        // ===== Build configuration =====
        const config = this.buildConfiguration(name);

        console.log('Saving mapping with name:', name);
        console.log('Configuration:', JSON.stringify(config));

        // ===== Save to Salesforce =====
        const configurationDisplayName = await createConfiguration({
            wrapperJson: JSON.stringify(config)
        });

        console.log(
            'Generated Configuration Display Name:',
            configurationDisplayName
        );

        // Send generated configuration name to parent
        this.dispatchEvent(new CustomEvent('mappingcreated', {
            detail: {
                mappingName: configurationDisplayName,
                objectName: this.selectedObject,
                operationType: this.selectedOperation,
                fileName: this.fileName
            }
        }));


        // Success
        this.showToast('Success', 'Mapping "' + name + '" created successfully!', 'success');
        this.showMappingPopup = false;
        this.mappingNameInput = '';
        this.mappingNameError = '';

    } catch (error) {
        console.error('Error saving mapping:', error);
        let msg = 'Failed to create mapping.';
        if (error && error.body && error.body.message) {
            msg = error.body.message;
        } else if (error && error.message) {
            msg = error.message;
        }
        this.mappingNameError = msg;
    } finally {
        this.isSaving = false;
    }
}

// ===== STEP 5: Configuration builder =====
buildConfiguration(mappingName) {
        const config = {
            objectName: this.selectedObject,
            operationType: this.selectedOperation,
            fileName: this.fileName,
            mappingName: mappingName,           // Popup se aaya naam
            mapping: []
        };

        // Transform selectedDropdownValues
        config.mapping = this.selectedDropdownValues.map(item => {
            let selectedLookupFields = '';
            let lookupObjectName = '';
            let targetObject = '';
            let matchField = '';
            let returnField = '';

            if (item.isComposite && item.value && item.value.includes(',')) {
                const parts = item.value.split(',').map(s => s.trim());

                const lookupValues = parts
                    .map(part => {
                        const val = item['lookupField_' + part];
                        return val ? String(val).toLowerCase() : null;
                    })
                    .filter(val => val !== null && val !== undefined && val.trim && val.trim() !== '');

                if (lookupValues.length > 0) {
                    selectedLookupFields = lookupValues.join(',');
                }

                if (item.isLookup) {
                    lookupObjectName = item.lookupObjectApiName || '';
                } else if (item.compositeTargetObject) {
                    lookupObjectName = item.compositeTargetObject;
                    targetObject = item.compositeTargetObject;
                    matchField = selectedLookupFields;
                    returnField = item.returnField || '';
                }
            } else if (item.isLookup && item.lookupField1) {
                selectedLookupFields = String(item.lookupField1).toLowerCase();
                lookupObjectName = item.lookupObjectApiName || '';
            }

            if (!item.isComposite && !item.isLookup && item.targetObject) {
                targetObject = item.targetObject;
                matchField = item.matchField;
                returnField = item.returnField;
                lookupObjectName = item.targetObject;
            }

            const isLookupFinal = item.isLookup || (!!item.targetObject);

            return {
                csvFieldName: item.csvFieldName,
                selectedField: item.selectedField,
                isLookup: isLookupFinal,
                selectedLookupFields: selectedLookupFields,
                lookupObject: lookupObjectName,
                whereClause: item.whereClause || '',
                isUniqueKey: item.isUniqueKey || false,
                targetObject: targetObject,
                matchField: matchField,
                returnField: returnField
            };
        });

        // Upsert ke liye unique key flag set karo
        if (this.selectedOperation === 'Upsert') {
            config.mapping = config.mapping.map(mapping => {
                const orig = this.selectedDropdownValues.find(
                    m => m.csvFieldName === mapping.csvFieldName && m.selectedField === mapping.selectedField
                );
                const isUniqueKey = this.createdUniqueKeyColumns.includes(orig ? orig.keyField : mapping.csvFieldName);
                return { ...mapping, isUniqueKey: isUniqueKey, lookupObject: mapping.lookupObject };
            });
        } else {
            config.mapping = config.mapping.map(mapping => {
                if (mapping.isLookup) {
                    return { ...mapping, lookupObject: mapping.lookupObject };
                }
                return mapping;
            });
        }

        return config;
}

    // ===== AUTO-POPULATE LOGIC (tan) =====
    normalizeHeader(header) {
        return (header || '').trim().toLowerCase();
    }

    getExistingMappedHeaders() {
        const records = this._existingMappingDetails || [];
        return records.flatMap(record =>
            (record.CgInfinity__File_Column_Name__c || '')
                .split(',')
                .map(header => this.normalizeHeader(header))
                .filter(Boolean)
        );
    }

    checkHeaderDifferences() {
        const csvHeaders = [...new Set((this.csvHeaders || []).map(h => this.normalizeHeader(h)).filter(Boolean))];
        const savedHeaders = [...new Set(this.getExistingMappedHeaders())];

        this.hasHeaderDifferences =
            csvHeaders.length !== savedHeaders.length ||
            csvHeaders.some(header => !savedHeaders.includes(header));
    }

    get showCreateMappingButton() {
        return !this.existingMappingMode;
    }

    get showModifyMappingButton() {
        const savedHeaders = new Set(this.getExistingMappedHeaders());
        const hasNewHeaders = (this.selectedDropdownValues || []).some(row => {
            const header = (row.csvFieldName || '').trim().toLowerCase();
            return header && !savedHeaders.has(header);
        });
        return !this.isMappingModified && hasNewHeaders;
    }

    get showCompositeUniqueKeys() {
        return !this.existingMappingMode;
    }

    populateExistingMapping() {
        const records = this._existingMappingDetails || [];
        if (!records.length) return;

        console.log('Populating existing mapping:', JSON.stringify(records));
        this.mappingName = records[0].CgInfinity__Mapping_Name__c || '';

        this.compositeHeaderOptions = [];
        this.compositeSections = [];
        this.createdCompositeMappings = [];
        this.checkHeaderDifferences();
        this.isMappingModified = false;
        const newSelectedDropdownValues = [];

        records.forEach((row) => {
            const isComposite = (row.CgInfinity__File_Column_Name__c || '').includes(',');

            if (isComposite) {
                const mappingId = this.compositeMappingIdCounter++;
                const compositeKey = row.CgInfinity__File_Column_Name__c;
                const keyField = `${compositeKey}__COMPOSITE_${mappingId}`;

                this.compositeHeaderOptions = [
                    ...this.compositeHeaderOptions,
                    { label: compositeKey, value: keyField, isSelected: false, isComposite: true }
                ];

                if (!this.csvHeaders.includes(compositeKey)) {
                    this.csvHeaders = [...this.csvHeaders, compositeKey];
                }

                this.createdCompositeMappings = [
                    ...this.createdCompositeMappings,
                    { id: mappingId, compositeKey, occurrence: 1 }
                ];
                this.compositeSections = [
                    ...this.compositeSections,
                    {
                        id: mappingId,
                        selectedColumns: compositeKey.split(',').map(s => s.trim()),
                        isMapped: true,
                        isButtonDisabled: true,
                        name1: 'composite1',
                        name2: 'composite2',
                        lookupField1: '',
                        lookupField2: ''
                    }
                ];

                const parts = compositeKey.split(',').map(s => s.trim());
                const storedLookupParts = (row.CgInfinity__Lookup_Field__c || '').split(',').map(s => s.trim());

                const compositeRow = {
                    csvFieldName: compositeKey,
                    selectedField: row.CgInfinity__Field_to_update__c || '',
                    isLookup: !!row.CgInfinity__Is_LookUp__c,
                    isCompositeLookup: !!row.CgInfinity__Is_LookUp__c,
                    keyField,
                    value: compositeKey,
                    isComposite: true,
                    lookupObjectName: '',
                    lookupObjectApiName: '',
                    lookupObjectOptions: [],
                    lookupObjectFields: [],
                    whereClause: row.CgInfinity__Lookup_Filter_Criteria__c || '',
                    returnField: row.CgInfinity__Lookup_Return_Field__c || '',
                    targetObject: '',
                    compositeTargetObject: '',
                    compositeTargetObjectFields: [],
                    matchField: '',
                    _rawLookupObjectName: row.CgInfinity__Lookup_Object_Name__c || ''
                };

                parts.forEach((part, i) => {
                    compositeRow['lookupField_' + part] = storedLookupParts[i] || '';
                });

                newSelectedDropdownValues.push(compositeRow);

            } else {
                newSelectedDropdownValues.push({
                    csvFieldName: row.CgInfinity__File_Column_Name__c || '',
                    selectedField: row.CgInfinity__Field_to_update__c || '',
                    isLookup: !!row.CgInfinity__Is_LookUp__c,
                    keyField: row.CgInfinity__File_Column_Name__c || `existing-${newSelectedDropdownValues.length}`,
                    value: undefined,
                    isComposite: false,
                    lookupObjectName: '',
                    lookupObjectApiName: '',
                    lookupObjectOptions: [],
                    lookupField1: row.CgInfinity__Is_LookUp__c ? row.CgInfinity__Lookup_Field__c : '',
                    whereClause: row.CgInfinity__Lookup_Filter_Criteria__c || '',
                    returnField: row.CgInfinity__Lookup_Return_Field__c || '',
                    _rawLookupField: row.CgInfinity__Lookup_Field__c || ''
                });
            }
        });

        // Merge missing CSV headers (New columns)
        const existingHeaders = new Set(newSelectedDropdownValues.map(row => this.normalizeHeader(row.csvFieldName)));
        
        this.csvHeaderOptions.forEach(header => {
            const normalizedHeader = this.normalizeHeader(header.value);
            if (!normalizedHeader || existingHeaders.has(normalizedHeader)) return;

            newSelectedDropdownValues.push({
                csvFieldName: header.value,
                selectedField: '',
                isLookup: false,
                isCompositeLookup: false,
                keyField: header.value,
                value: undefined,
                isComposite: false,
                lookupObjectName: '',
                lookupObjectApiName: '',
                lookupObjectOptions: [],
                lookupObjectFields: [],
                lookupField1: '',
                selectedLookupFields: '',
                whereClause: '',
                targetObject: '',
                targetObjectFields: [],
                compositeTargetObjectFields: [],
                matchField: '',
                returnField: '',
                isUniqueKey: false
            });
            existingHeaders.add(normalizedHeader);
        });

        this.selectedDropdownValues = [...newSelectedDropdownValues];

        // Reconstruct Unique Keys
        const operationFromRecord = records[0].CgInfinity__Operation__c || this.selectedOperation;
        if (operationFromRecord === 'Upsert') {
            this.createdUniqueKeyColumns = records.filter(r => r.CgInfinity__Is_Unique_Key__c).map(r => r.CgInfinity__File_Column_Name__c);
            this._uniqueKeyCreated = this.createdUniqueKeyColumns.length > 0;
            this.selectedUniqueKeyColumns = [...this.createdUniqueKeyColumns];
            this.uniqueKeyHeaderOptions = this.uniqueKeyHeaderOptions.map(opt => ({
                ...opt,
                isSelected: this.createdUniqueKeyColumns.includes(opt.value)
            }));
        }

        // Hydrate Lookups
        this.selectedDropdownValues.filter(r => r.isLookup && !r.isComposite && r.selectedField).forEach(r => this.hydrateLookupRow(r));
        this.selectedDropdownValues.filter(r => r.isComposite && r.isLookup && r._rawLookupObjectName).forEach(r => this.hydrateCompositeRow(r));
    }

    hydrateLookupRow(row) {
        const expectedSelectedField = row.selectedField;
        if (expectedSelectedField === 'Id') {
            getFields({ objectName: this.selectedObject }).then(fields => {
                const idx = this.selectedDropdownValues.findIndex(v => v.keyField === row.keyField);
                if (idx === -1) return;
                const current = this.selectedDropdownValues[idx];
                if (!current.isLookup || current.selectedField !== expectedSelectedField) return;
                
                const fieldOptions = fields.map(f => ({ label: f.label, value: f.apiName }));
                const match = fieldOptions.find(f => f.value.toLowerCase() === (row._rawLookupField || '').toLowerCase());
                
                this.selectedDropdownValues[idx] = {
                    ...current, lookupObjectApiName: this.selectedObject, lookupObjectName: this.selectedObject,
                    lookupObjectOptions: fieldOptions, lookupField1: match ? match.value : (row._rawLookupField || '')
                };
                this.selectedDropdownValues = [...this.selectedDropdownValues];
            }).catch(e => console.error(e));
            return;
        }

        getLookupFields({ parentObjectName: this.selectedObject, lookupFieldName: row.selectedField }).then(data => 
            getFields({ objectName: data.lookUpObjectName }).then(fields => {
                const idx = this.selectedDropdownValues.findIndex(v => v.keyField === row.keyField);
                if (idx === -1) return;
                const current = this.selectedDropdownValues[idx];
                if (!current.isLookup || current.selectedField !== expectedSelectedField) return;

                this.selectedDropdownValues[idx] = {
                    ...current,
                    lookupObjectApiName: data.lookUpObjectName,
                    lookupObjectName: this.convertApiNameToDisplayName(data.lookUpObjectName),
                    lookupObjectOptions: fields.map(f => ({ label: f.label, value: f.apiName })),
                    lookupField1: (fields.find(f => f.apiName.toLowerCase() === row._rawLookupField.toLowerCase()) || {}).apiName || ''
                };
                this.selectedDropdownValues = [...this.selectedDropdownValues];
            })
        ).catch(e => console.error(e));
    }

    hydrateCompositeRow(row) {
        const expectedValue = row.value;
        getFields({ objectName: row._rawLookupObjectName }).then(fields => {
            const idx = this.selectedDropdownValues.findIndex(v => v.keyField === row.keyField);
            if (idx === -1) return;
            const current = this.selectedDropdownValues[idx];
            if (!current.isLookup || current.value !== expectedValue) return;

            const fieldOptions = fields.map(f => ({ label: f.label, value: f.apiName }));
            const updated = { ...current };
            updated.lookupObjectApiName = row._rawLookupObjectName;
            updated.lookupObjectName = this.convertApiNameToDisplayName(row._rawLookupObjectName);
            updated.lookupObjectFields = fieldOptions;
            updated.lookupObjectOptions = fieldOptions;

            const parts = updated.value.split(',').map(s => s.trim());
            parts.forEach(part => {
                const propName = 'lookupField_' + part;
                const rawVal = updated[propName];
                if (rawVal) {
                    const match = fieldOptions.find(f => f.value.toLowerCase() === rawVal.toLowerCase());
                    updated[propName] = match ? match.value : rawVal;
                }
            });
            this.selectedDropdownValues[idx] = updated;
            this.selectedDropdownValues = [...this.selectedDropdownValues];
        }).catch(e => console.error(e));
    }

    // ===== MODIFY MAPPING LOGIC (tan) =====
    async handleModifyMappingClick() {
        try {
            const savedHeaders = new Set(this.getExistingMappedHeaders());
            const newRows = (this.selectedDropdownValues || []).filter(row => {
                const csvHeader = (row.csvFieldName || '').trim().toLowerCase();
                return csvHeader && !savedHeaders.has(csvHeader);
            });

            if (!newRows.length) {
                this.showToast('Information', 'There are no new columns to append.', 'info');
                return;
            }

            const unmappedRow = newRows.find(row => !row.selectedField);
            if (unmappedRow) {
                this.showToast('Error', `Select a Salesforce field for "${unmappedRow.csvFieldName}".`, 'error');
                return;
            }

            if (!this.existingMappingDisplayName) {
                this.showToast('Error', 'Selected mapping display name is empty.', 'error');
                return;
            }

            const configuration = {
                objectName: this.selectedObject,
                operationType: this.selectedOperation,
                fileName: this.fileName,
                mappingName: this.mappingName,
                mapping: newRows.map(row => {
                    const lookupFields = row.lookupField1 ?? row.selectedLookupFields ?? '';
                    return {
                        csvFieldName: String(row.csvFieldName || ''),
                        selectedField: String(row.selectedField || ''),
                        isLookup: row.isLookup === true,
                        selectedLookupFields: Array.isArray(lookupFields) ? lookupFields.join(',') : String(lookupFields),
                        lookupObject: String(row.lookupObjectApiName || row.lookupObjectName || ''),
                        whereClause: String(row.whereClause || ''),
                        isUniqueKey: row.isUniqueKey === true,
                        targetObject: String(row.targetObject || ''),
                        matchField: String(row.matchField || ''),
                        returnField: String(row.returnField || '')
                    };
                })
            };

            await appendNewMappingColumns({
                wrapperJson: JSON.stringify(configuration),
                configurationDisplayName: this.existingMappingDisplayName
            });

            this.isMappingModified = true;
            this.showToast('Success', 'New columns appended to the existing mapping.', 'success');
        } catch (error) {
            console.error('Append mapping error:', JSON.stringify(error));
            this.showToast('Error', error?.body?.message || error?.message || 'Unable to append new columns.', 'error');
        }
    }
    
   // till here auto populate and modify mapping button logic ends here (tan)

    createInitialCsvMapping() {
        for (let i = 0; i < this.csvHeaders.length; i++) {
            this.selectedDropdownValues.push(
                { csvFieldName: this.csvHeaders[i],
                  selectedField: this.csvHeaders[i],
                  isLookup: false,
                  keyField: this.csvHeaders[i],
                  lookupObjectName: '',
                  lookupObjectApiName: '',
                  whereClause: '',
                  lookupObjectOptions: [],
                  lookupField1: '',
                  isComposite: false,
                  targetObject: '',
                  targetObjectFields: [],
                  compositeTargetObjectFields: [],
                  matchField: '',
                  returnField: ''
                 });
        }
    }
    handleDeleteMapping(event)
    {
        const keyField = event.detail.keyField;
        this.selectedDropdownValues = this.selectedDropdownValues.filter(
        mapping => mapping.keyField !== keyField
    );
    }
   
    get tableData(){
        return this.selectedDropdownValues.map(item => {
            let lookupMapping = '';
            let lookupObjectName = item.lookupObjectName || '';
            let returnField = item.returnField || ' ';
                    
            // For composite mappings, collect all lookupField_* values
            if (item.isComposite && item.value) {
                console.log('>>> ENTERING COMPOSITE BRANCH for', item.csvFieldName);
                const parts = item.value.split(',').map(s => s.trim());
                
                const lookupValues = parts
                    .map(part => {
                        const propName = 'lookupField_' + part;
                        const fieldValue = item[propName];
                        console.log(`  Looking for '${propName}': ${fieldValue}`);
                        // Return the field value if it exists and is not empty
                        if (fieldValue && typeof fieldValue === 'string' && fieldValue.trim()) {
                            return fieldValue.trim();
                        }
                        return null;
                    })
                    .filter(val => val !== null && val !== undefined);
                
                console.log('  Collected lookupValues:', lookupValues);
                
                if (lookupValues.length > 0) {
                    lookupMapping = lookupValues.join(',');
                }
                
                // For composite non-lookup: use compositeTargetObject as lookup object name
                if (!item.isLookup && item.compositeTargetObject) {
                    lookupObjectName = item.compositeTargetObject;
                    returnField = item.returnField || '';
                }
                // For composite lookup: use lookupObjectName (already set)
                console.log('  Final lookupMapping:', lookupMapping);
                
            } else if (item.isLookup && item.lookupField1) {
                // For non-composite lookups
                console.log('>>> ENTERING NON-COMPOSITE LOOKUP BRANCH for', item.csvFieldName);
                lookupMapping = item.lookupField1;
            } else if (!item.isLookup && item.targetObject) {
                // For single non-lookup cross-object mapping
                console.log('>>> ENTERING SINGLE NON-LOOKUP BRANCH for', item.csvFieldName);
                lookupObjectName = item.targetObject;
                lookupMapping = item.matchField || '';
                returnField = item.returnField || '';
            }
            
            console.log('tableData - returning object for', item.csvFieldName, '{ lookupObjectName:', lookupObjectName, ', lookupField1:', lookupMapping, ', returnField:', returnField, '}');
            
            return {
                ...item,
                lookupObjectName,
                lookupField1: lookupMapping,
                returnField
            };
        });
    }
 
    // Composite Mapping Handlers
    handleColumnCheckboxChange(event) {
        const sectionId = parseInt(event.target.dataset.sectionid, 10);
        const columnValue = event.target.dataset.column;
        const isChecked = event.target.checked;
        const sectionIdx = this.compositeSections.findIndex(sec => sec.id === sectionId);
        if (sectionIdx === -1) return;
        let section = this.compositeSections[sectionIdx];
        if (isChecked) {
            if (!section.selectedColumns.includes(columnValue)) {
                section.selectedColumns = [...section.selectedColumns, columnValue];
            }
        } else {
            section.selectedColumns = section.selectedColumns.filter(col => col !== columnValue);
        }
        // Update the section in the array
        this.compositeSections = [
            ...this.compositeSections.slice(0, sectionIdx),
            { ...section },
            ...this.compositeSections.slice(sectionIdx + 1)
        ];
    }
 
    handleRemoveSelectedColumn(event) {
        const sectionId = parseInt(event.currentTarget.dataset.sectionid, 10);
        const columnValue = event.currentTarget.dataset.column;
        const sectionIdx = this.compositeSections.findIndex(sec => sec.id === sectionId);
        if (sectionIdx === -1) return;
        let section = this.compositeSections[sectionIdx];
        section.selectedColumns = section.selectedColumns.filter(col => col !== columnValue);
        this.compositeSections = [
            ...this.compositeSections.slice(0, sectionIdx),
            { ...section },
            ...this.compositeSections.slice(sectionIdx + 1)
        ];
    }
 
    handleCreateCompositeMapping(event) {
        const sectionId = parseInt(event.currentTarget.dataset.sectionid, 10);
        const sectionIdx = this.compositeSections.findIndex(sec => sec.id === sectionId);
        if (sectionIdx === -1) return;
        let section = this.compositeSections[sectionIdx];
        // Prevent duplicate mapping creation for this section
        if (section.isMapped || section.isButtonDisabled) {
            return;
        }
        if (section.selectedColumns.length > 1) {
            const compositeKey = section.selectedColumns.join(',');
            const existingCount = this.csvHeaders.filter(h => h === compositeKey).length;
            const occurrence = existingCount + 1;
            const mappingId = this.compositeMappingIdCounter++;
            const newMapping = {
                id: mappingId,
                compositeKey: compositeKey,
                occurrence: occurrence,
            };
            this.createdCompositeMappings = [...this.createdCompositeMappings, newMapping];
            this.csvHeaders = [...this.csvHeaders, compositeKey];
            const uniqueKeyField = `${compositeKey}__COMPOSITE_${mappingId}`;
            this.compositeHeaderOptions = [
                ...this.compositeHeaderOptions,
                { label: compositeKey, value: uniqueKeyField, isSelected: false, isComposite: true }
            ];
            this.selectedDropdownValues = [...this.selectedDropdownValues, {
                csvFieldName: compositeKey,
                selectedField: compositeKey,
                isLookup: false,
                keyField: uniqueKeyField,
                value: compositeKey, // Store the composite key value for splitting in allHeaderOptions
                lookupObjectName: '',
                lookupObjectApiName: '',
                whereClause: '',
                lookupObjectOptions: [],
                lookupField1: '',
                selectedLookupFields: '',
                extraCsvField: '',
                isComposite: true,
                targetObject: '',
                targetObjectFields: [],
                compositeTargetObjectFields: [],
                matchField: '',
                returnField: ''
            }];
            // Mark this section as mapped and disable button only for this section
            section.isMapped = true;
            section.isButtonDisabled = true;
            this.compositeSections = [
                ...this.compositeSections.slice(0, sectionIdx),
                { ...section },
                ...this.compositeSections.slice(sectionIdx + 1)
            ];
        } else {
            this.showToast('Error', 'Please select at least two columns to create a composite mapping.', 'error');
        }
    }

       handleDeleteColumnMapping(event) {
            const keyField = event.currentTarget.dataset.columnvalue;
           
            // Check if this is a composite mapping by looking for the __COMPOSITE_ pattern
            const isComposite = keyField && keyField.includes('__COMPOSITE_');
           
            if (isComposite) {
                // Extract the mapping ID from the keyField (format: compositeKey__COMPOSITE_id)
                const parts = keyField.split('__COMPOSITE_');
                const mappingId = parseInt(parts[1], 10);
               
                // Find the composite mapping
                const mapping = this.createdCompositeMappings.find(m => m.id === mappingId);
               
                if (mapping) {
                    const sectionId = mapping.sectionId;
                    const compositeKey = mapping.compositeKey;
                   
                    // Remove from selectedDropdownValues
                    this.selectedDropdownValues = this.selectedDropdownValues.filter(
                        row => row.keyField !== keyField
                    );
                   
                    // Remove from compositeHeaderOptions
                    this.compositeHeaderOptions = this.compositeHeaderOptions.filter(
                        opt => opt.value !== keyField
                    );
                   
                    // Remove from csvHeaders
                    this.csvHeaders = this.csvHeaders.filter(h => h !== compositeKey);
                   
                    // Remove from createdCompositeMappings
                    this.createdCompositeMappings = this.createdCompositeMappings.filter(
                        m => m.id !== mappingId
                    );
                   
                    // Reset the section state so it can be used again
                    const sectionIdx = this.compositeSections.findIndex(sec => sec.id === sectionId);
                    if (sectionIdx !== -1) {
                        let section = this.compositeSections[sectionIdx];
                        section.isMapped = false;
                        section.isButtonDisabled = false;
                        this.compositeSections = [
                            ...this.compositeSections.slice(0, sectionIdx),
                            { ...section },
                            ...this.compositeSections.slice(sectionIdx + 1)
                        ];
                    }
                   
                    this.showToast('Delete', 'Composite mapping removed.', 'success');
                }
            } else {
                // Handle regular (non-composite) column mapping deletion
                // Remove from selectedDropdownValues (main mapping array)
                this.selectedDropdownValues = this.selectedDropdownValues.filter(
                    mapping => mapping.keyField !== keyField
                );
               
                // Remove from csvHeaderOptions (for non-composite columns)
                this.csvHeaderOptions = this.csvHeaderOptions.filter(
                    col => col.value !== keyField
                );
               
                this.showToast('Deletesss', 'Column mapping removed.', 'success');
            }
        }
 
    handleDeleteCompositeMapping(event) {
        const mappingId = parseInt(event.currentTarget.dataset.id, 10);
        const mapping = this.createdCompositeMappings.find(m => m.id === mappingId);
       
        if (mapping) {
            const compositeKey = mapping.compositeKey;
            const uniqueKeyField = `${compositeKey}__COMPOSITE_${mappingId}`;
 
            const rowIndexToRemove = this.selectedDropdownValues.findIndex(
                row => row.keyField === uniqueKeyField
            );
            if (rowIndexToRemove !== -1) {
                this.csvHeaders.splice(rowIndexToRemove, 1);
            }
 
            this.selectedDropdownValues = this.selectedDropdownValues.filter(
                row => row.keyField !== uniqueKeyField
            );
 
            this.compositeHeaderOptions = this.compositeHeaderOptions.filter(opt => opt.value !== uniqueKeyField);
        }
       
        this.createdCompositeMappings = this.createdCompositeMappings.filter(
            mapping => mapping.id !== mappingId
        );
        this.compositeSections = this.compositeSections.filter(sec => sec.id !== mappingId);
        this.compositeSections = this.compositeSections.map((sec, idx) => ({ ...sec, id: idx }));
        console.log('Mapping deleted, remaining:', this.createdCompositeMappings);
        console.log('Updated csvHeaders:', this.csvHeaders);
    }
 
    get hasCompositeMappings() {
        return this.createdCompositeMappings && this.createdCompositeMappings.length > 0;
    }
 
    // Get all header options for rendering (original + composite columns)
    get allHeaderOptions() {
        const base = [...this.csvHeaderOptions, ...this.compositeHeaderOptions];
        return base.map(col => {
            const sd = this.selectedDropdownValues.find(s => s.keyField === col.value);
            let compositeDropdowns = [];
            // Use sd.value if composite, otherwise use col.value
            const keyToSplit = sd && sd.value ? sd.value : col.value;
            if (col.isComposite && keyToSplit) {
                const parts = keyToSplit.split(',').map(s => s.trim());
                // For composite non-lookup: use compositeTargetObjectFields if targetObject is set
                // For composite lookup: use lookupObjectOptions
                let options = [];
                if (sd && sd.targetObject && sd.compositeTargetObjectFields) {
                    // Non-lookup composite with target object selected
                    options = [...sd.compositeTargetObjectFields];
                } else if (sd && sd.lookupObjectOptions) {
                    // Lookup composite
                    options = [...sd.lookupObjectOptions];
                }
                compositeDropdowns = parts.map(part => {
                    let partOptions = options;
                    // Value for non-lookup composite: sd.lookupField_[part]
                    let value = '';
                    if (sd && sd['lookupField_' + part] !== undefined) {
                        value = sd['lookupField_' + part];
                    }
                    // ==== ADDED: per-part search filter ====
                    const searchKey = (col.value || '') + '::' + part;
                    const term =
                        (this.searchCompositeDropdownOptions || {})[searchKey] || '';
                    return {
                        label: part,
                        value: value,
                        options: partOptions,
                        name: part,
                        compositeLabel: 'Field: ' + part + ' - Corresponding SF Field'
                    };
                });
            }
            console.log('allHeaderOptions - col:', col.value, 'isComposite:', col.isComposite, 'keyToSplit:', keyToSplit, 'compositeDropdowns length:', compositeDropdowns.length, 'compositeDropdowns:', compositeDropdowns, 'targetObject:', sd ? sd.targetObject : 'none', 'compositeTargetObjectFields:', sd ? sd.compositeTargetObjectFields : 'none');
            return {
                ...col,
                mappedField: sd ? sd.selectedField : '',
                isLookupSelected: sd ? !!sd.isLookup : false,
                lookupObjectName: sd ? sd.lookupObjectName : '',
                lookupObjectApiName: sd ? sd.lookupObjectApiName : '',
                lookupObjectOptions: sd ? (sd.lookupObjectOptions || []) : [],
                lookupField1: sd ? sd.lookupField1 : '',
                whereClause: sd ? sd.whereClause : '',
                compositeDropdowns,
                // Cross-object mapping fields (for non-lookup only)
                targetObject: sd ? sd.targetObject : '',
                targetObjectFields: sd ? (sd.targetObjectFields || []) : [],
                compositeTargetObjectFields: sd ? (sd.compositeTargetObjectFields || []) : [],
                matchField: sd ? sd.matchField : '',
                returnField: sd ? sd.returnField : '',
                // ==== ADDED: filtered lists for searchable dropdowns ====
                filteredLookupObjectOptions: this.filterByTerm(
                    sd ? (sd.lookupObjectOptions || []) : [],
                    this.searchLookupObjectOptionsPerRow[col.value] || ''
                ),
                filteredTargetObjectFields: this.filterByTerm(
                    sd ? (sd.targetObjectFields || []) : [],
                    this.searchTargetObjectOptions[col.value] || ''
                ),
                filteredCompositeTargetObjectFields: this.filterByTerm(
                    sd ? (sd.compositeTargetObjectFields || []) : [],
                    this.searchCompositeTargetObjectOptions[col.value] || ''
                )
            };
        });
    }
 
    // Options for lookup object combobox (derived from lookup fields list)
    get lookupObjectOptions() {
        if (!this.fieldsWithLookupList) return [];
        return this.fieldsWithLookupList.map(f => ({ label: f.label, value: f.apiName }));
    }
 
    // Options for CSV header selection used in extra CSV comboboxes
    get csvHeaderComboboxOptions() {
        return this.csvHeaders.map(h => ({ label: h, value: h }));
    }
 
    // Separate getters for each section to avoid shared state
    get uniqueKeyColumnsForCheckbox() {
        return this.uniqueKeyHeaderOptions;
    }
    get compositeColumnsForCheckbox() {
        return this.csvHeaderOptions;
    }
 
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
 
    get compositeColumnsForCheckbox() {
        const compositeKeyValues = this.compositeHeaderOptions
            .filter(opt => opt.isComposite)
            .map(opt => opt.value);
       
        return this.csvHeaders.map(header => ({
            label: header,
            value: header,
            isChecked: false,
            isComposite: false
        })).filter(col => !compositeKeyValues.includes(col.value));
    }

        // ===== SEARCH HANDLERS (added) =====
    filterByTerm(list, term) {
        if (!Array.isArray(list)) {
            return [];
        }
        const needle = (term || '').toLowerCase().trim();
        if (!needle) {
            return list;
        }
        return list.filter(o => {
            const l = (o && o.label ? String(o.label) : '').toLowerCase();
            const v = (o && o.value ? String(o.value) : '').toLowerCase();
            return l.includes(needle) || v.includes(needle);
        });
    }

    handleSearchChange(event) {
        const src = event.currentTarget.dataset.searchsource;
        const key = event.currentTarget.dataset.searchkey;
        const part = event.currentTarget.dataset.searchpart;
        const term = event.target.value || '';

        switch (src) {
            case 'fieldOptions':
                this.searchFieldOptions = term;
                break;

            case 'lookupObjectOptions':
                if (key) {
                    this.searchLookupObjectOptionsPerRow = {
                        ...this.searchLookupObjectOptionsPerRow,
                        [key]: term
                    };
                }
                break;

            case 'targetObjectFields':
                if (key) {
                    this.searchTargetObjectOptions = {
                        ...this.searchTargetObjectOptions,
                        [key]: term
                    };
                }
                break;

            case 'compositeTargetObjectFields':
                if (key) {
                    this.searchCompositeTargetObjectOptions = {
                        ...this.searchCompositeTargetObjectOptions,
                        [key]: term
                    };
                }
                break;

            case 'compositeDropdownOptions':
                if (key && part) {
                    this.searchCompositeDropdownOptions = {
                        ...this.searchCompositeDropdownOptions,
                        [key + '::' + part]: term
                    };
                }
                break;

            default:
                break;
        }
    }
    
        get filteredFieldOptions() {
        return this.filterByTerm(this.fieldOptions, this.searchFieldOptions);
    }
}