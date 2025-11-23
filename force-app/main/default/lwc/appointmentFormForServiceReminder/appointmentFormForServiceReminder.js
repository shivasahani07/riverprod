import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import getvehicleRecord from '@salesforce/apex/AppointmentFormController.getvehicleRecord';
import getCurrentServiceCenter from '@salesforce/apex/AppointmentFormController.getCurrentServiceCenter';
import getSlotItems from '@salesforce/apex/AppointmentFormController.getSlotItems';
import createAppointmentforServiceAppointment from '@salesforce/apex/AppointmentFormController.createAppointmentforServiceAppointment';
import getPicklistValues from '@salesforce/apex/AppointmentFormController.getPicklistValues';
import relatedToId from '@salesforce/apex/AppointmentFormController.relatedToId';//added by Aniket for Shubham's new requirement 
import warningLogo from '@salesforce/resourceUrl/Warning_LOGO';//added by Aniket

export default class AppointmentForm extends NavigationMixin(LightningElement) {
    @api recordId;

    @track showSuccessAnimation = false;//added by Aniket


    @track selectedServiceCenter = '';
    @track appointmentDate = '';
    @track vrn = '';
    @track contactNumber = '';
    @track appointmentDecription = '';

    // updated to handle multiple slotIds
    @track appointmentSlotIds = [];
    @track selectedSlotItem = '';
    @track slotSearchTriggered = false;
    @track slotsAvailable = false;
    @track slotItemOptions = [];
    @track showDescriptionField = false;
    @track isLoading = false;

    minDate;
    serviceCenterId = '';
    serviceCenterName = '';

    relatedToId='';//added by Aniket 
    showWarning=false;//added by Aniket
    warningLogo=warningLogo;//added by Aniket

    @wire(getCurrentServiceCenter)
    wiredCenterName({ error, data }) {
        if (data) {
            this.serviceCenterId = data.accountId;
            this.serviceCenterName = data.accountName;
            console.log('this.serviceCenterId==>',this.serviceCenterId);
        } else if (error) {
            console.error('Could not get center name', error);
        }
    }

    connectedCallback() {
        this.getTheRelatedToId();//added by Aniket;
        this.loadPicklistValues();
        if (!this.recordId) {
            const url = window.location.href;
            const match = url.match(/\/case\/([^/]+)/);
            if (match) {
                this.recordId = match[1];
            }
        }

        if (this.recordId) {
            this.fetchVehicleData();
        }

        this.setMinDate();
    }

    //Added by Aniket
     getTheRelatedToId(){
        debugger;
        relatedToId({recordId:this.recordId})
        .then(result=>{
            this.relatedToId = result;
            console.log('this.relatedToId=====>',this.relatedToId);
            if(this.relatedToId.startsWith('a1')){
                this.showWarning=true;
            }
        })
        .catch(error=>{
            console.log('Error Is==>',JSON.stringigy(error));
        })
     }
    //////////////

    loadPicklistValues() {
        getPicklistValues({ objectApiName: 'ServiceAppointment', fieldApiName: 'Type_Of_Requested_Services__c' })
            .then(result => {
                this.options = result.map(value => ({
                    label: value,
                    value: value
                }));
            })
            .catch(error => {
                console.error('Error loading picklist values', error);
            });
    }

    setMinDate() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        this.minDate = `${year}-${month}-${day}`;
    }

    fetchVehicleData() {
        getvehicleRecord({ sourceIdStr: this.recordId })
            .then(r => {
                if (r) {
                    this.vrn = r.VehicleRegistrationNumber || '';
                    this.contactNumber = r.CurrentOwner?.Phone || '';
                }
            })
            .catch(() => this.showToast('Error', 'Failed to load vehicle data', 'error'));
    }

    handleDateChange(e) {
        debugger;
        this.appointmentDate = e.target.value;

        const selectedDate = new Date(this.appointmentDate);
        const today = new Date();

        selectedDate.setHours(0, 0, 0, 0);
        today.setHours(0, 0, 0, 0);

        if (selectedDate >= today) {
            this.loadSlotItems();
        } else {
            this.appointmentSlotIds = [];
            this.slotItemOptions = [];
            this.slotsAvailable = false;
            this.selectedSlotItem = '';
        }
    }

    handleSlotItemChange(e) {
        this.selectedSlotItem = e.detail.value;
    }

    handleAppointmentDesc(e) {
        this.appointmentDecription = e.detail.value;
    }

    handleSelectServices(event) {
        this.selectedValue = event.detail.value;
        console.log('Selected Service:', this.selectedValue);
    }

    loadSlotItems() {
        debugger;
        if (!this.serviceCenterId || !this.appointmentDate) return;

        this.slotSearchTriggered = true;

        getSlotItems({
            serviceCenterId: this.serviceCenterId,
            appointmentDate: this.appointmentDate
        })
            .then(res => {
                // update: now storing multiple slotIds
                this.appointmentSlotIds = res.slotIds || [];

                const items = (res.slotItems || []).map(i => {
                    let start = new Date(i.Start_Time__c);
                    let end = new Date(i.End_Time__c);

                    // Convert UTC to IST
                    start.setMinutes(start.getMinutes() - 330);
                    end.setMinutes(end.getMinutes() - 330);

                    const options = { hour: '2-digit', minute: '2-digit', hour12: true };

                    return {
                        label: `${i.Name} | ${start.toLocaleTimeString([], options)} - ${end.toLocaleTimeString([], options)}`,
                        value: i.Id
                    };
                });

                this.slotItemOptions = items;
                this.slotsAvailable = items.length > 0;

                this.showDescriptionField = this.slotsAvailable;
                this.selectedSlotItem = '';
            })
            .catch(err => {
                this.appointmentSlotIds = [];
                this.slotItemOptions = [];
                this.slotsAvailable = false;
                this.showToast(
                    'Error',
                    err?.body?.message || 'Failed to load slot items',
                    'error'
                );
            });
    }

    handleSubmit() {
        debugger;
         this.isLoading = true;
        if (this.isSubmitDisabled) {
            this.showToast('Missing Fields',
                'Please fill all fields including slot item.',
                'warning');
            return;
        }
        setTimeout(()=>{
              createAppointmentforServiceAppointment({
            serviceAppId: this.recordId,
            accountId: this.serviceCenterId,
            vrn: this.vrn,
            appointmentDate: this.appointmentDate,
            contactNumber: this.contactNumber,
            serviceType: this.selectedValue,
            // ⚡️ choose the first slotId if multiple
            slotId: this.appointmentSlotIds.length ? this.appointmentSlotIds[0] : null,
            slotItemId: this.selectedSlotItem,
            appointmentDecription: this.appointmentDecription
        })
            .then(appointmentId => {
                this.showToast('Success', 'Appointment created successfully.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
                this.isLoading = false;
                this.showSuccessAnimation = true;

                setTimeout(()=>{
                     //this.closeModal();
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: appointmentId,
                        objectApiName: 'Appointment__c',
                        actionName: 'view'
                    }
                });
                 this.closeModal();
                },4000)
                
            })
            .catch(err => this.showToast('Error',
                err?.body?.message || 'Error creating appointment.',
                'error'))
                  
              .finally(() => {
        this.isLoading = false; // hide spinner only after Apex call finishes
    });    
        },3000)
      
        
    }

    showToast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }

    get isSubmitDisabled() {
        const baseFieldsFilled = this.serviceCenterId &&
            this.vrn &&
            this.contactNumber &&
            this.appointmentDate &&
            this.selectedSlotItem &&
            this.appointmentSlotIds.length;

        return this.showDescriptionField
            ? !(baseFieldsFilled && this.appointmentDecription)
            : !baseFieldsFilled;
    }
    closeModal() {
        // const closeEvent = new CustomEvent('closemodal');
        // this.dispatchEvent(closeEvent);
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}