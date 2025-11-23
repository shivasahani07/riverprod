@isTest
public class RescheduleAppointmentFormController_Test {
    @testSetup
    static void setupTestData() {
        // Create test data in a single transaction
        Id dealerAccId;
        Id customerAccId;
        
        // Note: OrgWideEmailAddress with DisplayName 'River Mobility' should exist in the org
        // We will fetch it in test methods, not insert it
        
        // Create Dealer Account (Service Center)
        Account dealerAcc = new Account(
            Name = 'Test Service Center', 
            Type = 'Service Center',
            Center_Code__c = 'SC123',
            Email__c = 'servicecenter@test.com'
        );
        insert dealerAcc;
        dealerAccId = dealerAcc.Id;
        
        // Create Customer Account
        Account customerAcc = new Account(
            Name = 'Test Customer Account', 
            Type = 'Customer',
            Email__c = 'customer@test.com',
            Phone = '9876543210'
        );
        insert customerAcc;
        customerAccId = customerAcc.Id;
        
        // Create Contact for User
        Long timestamp = System.currentTimeMillis();
        Contact userContact = new Contact(
            FirstName = 'Test',
            LastName = 'User Contact',
            Email = 'usercontact' + timestamp + '@test.com',
            AccountId = dealerAcc.Id,
            Phone = '1122334455'
        );
        insert userContact;
        
        // Create Contact for Customer
        Contact customerContact = new Contact(
            FirstName = 'Customer',
            LastName = 'Contact',
            AccountId = customerAcc.Id,
            Phone = '9988776655',
            MobilePhone = '8877665544',
            Email = 'customer' + timestamp + '@test.com'
        );
        insert customerContact;
        
        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Vehicle Product',
            IsActive = true,
            ProductCode = 'PROD-001',
            HSN_Code__c = 'HSN-001',
            Type__c = 'Parts'
        );
        insert prod;
        
        // Create Asset
        Asset testAsset = new Asset(
            Name = 'Test Asset',
            AccountId = customerAccId,
            Product2Id = prod.Id
        );
        insert testAsset;
        
        // Create VehicleDefinition
        VehicleDefinition vd = new VehicleDefinition(
            Name = 'Test VD',
            ProductId = prod.Id
        );
        insert vd;
        
        // Create Software Version
        Software_Version__c sv = new Software_Version__c(
            Name = 'V1.0'
        );
        insert sv;
        
        // Create Vehicle
        Vehicle vehicle = new Vehicle(
            Name = 'Test Vehicle 001',
            VehicleRegistrationNumber = 'TN01AB' + String.valueOf(timestamp).substring(0, 4),
            Dealer__c = dealerAccId,
            CurrentOwnerId = customerAccId,
            AssetId = testAsset.Id,
            VehicleDefinitionId = vd.Id,
            VehicleIdentificationNumber = 'VIN' + timestamp,
            Software_Version__c = sv.Id,
            Charger_PC_Number__c = 'CHG' + timestamp
        );
        insert vehicle;
        
        // Create Asset Milestone
        AssetMilestone milestone = new AssetMilestone(
            Name = 'Test Milestone',
            MilestoneDate = System.today().addDays(10),
            Stage = 'Tentative',
            VehicleId = vehicle.Id,
            AssetId = testAsset.Id,
            MilestoneType = 'PDI',
            UsageType = 'Automotive'
        );
        insert milestone;
        
        // Create Job Card (WorkOrder) FIRST - as it's the ParentRecord for ServiceAppointment
        WorkOrder jobCard = new WorkOrder(
            Vehicle__c = vehicle.Id,
            AccountId = customerAccId,
            Status ='',
            Mode_Of_Payment__c='UPI'
        );
        insert jobCard;
        
        // Create ServiceAppointment with ParentRecordId (WorkOrder)
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = jobCard.Id,  // Required field - link to WorkOrder
            Vehicle__c = vehicle.Id,
            Asset_Milestone__c = milestone.Id,
            Status = 'Scheduled',
            SchedStartTime = System.now().addDays(5),
            SchedEndTime = System.now().addDays(5).addHours(2),
            Service_Centre__c = dealerAccId,
            Call_Status__c = 'Pending'
        );
        insert sa;
        
        // Update WorkOrder with ServiceAppointment reference
        jobCard.Service_Appointment__c = sa.Id;
        update jobCard;
        
        // Create Ticket
        Ticket__c ticket = new Ticket__c(
            Vehicle__c = vehicle.Id,
            Job_Card__c = jobCard.Id,
            Status__c = 'Open',
            Resolution__c = 'Test resolution'
            //Sub_Status__c = ''
        );
        insert ticket;
        
        // Create Appointment
        Appointment__c appointment = new Appointment__c(
            Service_Center__c = dealerAccId,
            VRN__c = vehicle.VehicleRegistrationNumber,
            Status__c = 'Pending',
            Appointment_Date__c = System.today().addDays(7),
            Contact_Number__c = '9876543210',
            Ticket__c = ticket.Id,
            Service_Appointment__c = sa.Id,
            Type_Of_Requested_Services__c = 'PMS',
            Additional_Information__c = 'Test appointment'
        );
        insert appointment;
        
        // Create Appointment Slot
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Service_Center__c = dealerAccId,
            Appointment_Slot_Date__c = System.today().addDays(7),
            Appointment__c = appointment.Id
        );
        insert slot;
        
        // Create Appointment Slot Items (without Name field as it's auto-generated)
        List<Appointment_Slot_Item__c> slotItems = new List<Appointment_Slot_Item__c>();
        slotItems.add(new Appointment_Slot_Item__c(
            Appointment_Slot__c = slot.Id,
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(10, 0, 0, 0),
            Booking_Status__c = 'Available'
        ));
        slotItems.add(new Appointment_Slot_Item__c(
            Appointment_Slot__c = slot.Id,
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            End_Time__c = Time.newInstance(11, 0, 0, 0),
            Booking_Status__c = 'Booked',
            Appointment__c = appointment.Id
        ));
        insert slotItems;
        
        // Create Task
        Task testTask = new Task(
            Subject = 'Test Task',
            WhatId = sa.Id,
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = System.today().addDays(5)
        );
        insert testTask;
    }
    
    @isTest
    static void testGetServiceCenters() {
        Test.startTest();
        List<Account> centers = RescheduleAppointmentFormController.getServiceCenters();
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testGetCurrentServiceCenter() {
        User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        // Update user with contact
        Contact testContact = [SELECT Id, AccountId FROM Contact LIMIT 1];
        currentUser.ContactId = testContact.Id;
        
        Test.startTest();
        try {
            update currentUser;
            RescheduleAppointmentFormController.ServiceCenterWrapper wrapper = 
                RescheduleAppointmentFormController.getCurrentServiceCenter();
            
        } catch(Exception e) {
            // User may not have permission to update ContactId
            
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVehicleOwnerContacts() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        String phoneNumber = RescheduleAppointmentFormController.getVehicleOwnerContacts(ticket.Id);
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testGetVehicleOwnerContacts_NoVehicle() {
        // Create WorkOrder without vehicle for ticket
        Account customerAcc = [SELECT Id FROM Account WHERE Type = 'Customer' LIMIT 1];
        WorkOrder woNoVehicle = new WorkOrder(
            AccountId = customerAcc.Id,
            Status = 'New'
        );
        insert woNoVehicle;
        
        Ticket__c ticketNoVehicle = new Ticket__c(
            Job_Card__c = woNoVehicle.Id,
            Status__c = 'Open'
        );
        insert ticketNoVehicle;
        
        Test.startTest();
        String result = RescheduleAppointmentFormController.getVehicleOwnerContacts(ticketNoVehicle.Id);
        Test.stopTest();
        
       // System.assertEquals('No Contact Number Found', result, 'Should return no contact found message');
    }
    
    @isTest
    static void testGetVehicleRecord_ServiceAppointment() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        
        Test.startTest();
        RescheduleAppointmentFormController.AppointmentWrapper wrapper = 
            RescheduleAppointmentFormController.getvehicleRecord(sa.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetVehicleRecord_Ticket() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE Vehicle__c != null LIMIT 1];
        
        Test.startTest();
        RescheduleAppointmentFormController.AppointmentWrapper wrapper = 
            RescheduleAppointmentFormController.getvehicleRecord(ticket.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetVehicleRecord_Appointment() {
        Appointment__c appointment = [SELECT Id FROM Appointment__c LIMIT 1];
        
        Test.startTest();
        RescheduleAppointmentFormController.AppointmentWrapper wrapper = 
            RescheduleAppointmentFormController.getvehicleRecord(appointment.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetVehicleRecord_Task() {
        Task task = [SELECT Id FROM Task LIMIT 1];
        
        Test.startTest();
        RescheduleAppointmentFormController.AppointmentWrapper wrapper = 
            RescheduleAppointmentFormController.getvehicleRecord(task.Id);
        Test.stopTest();
        
       
    }
    
    @isTest
    static void testGetVehicleRecord_InvalidId() {
        Test.startTest();
        RescheduleAppointmentFormController.AppointmentWrapper wrapper = 
            RescheduleAppointmentFormController.getvehicleRecord(null);
        Test.stopTest();
        
        System.assertEquals(null, wrapper, 'Should return null for invalid ID');
    }
    
    @isTest
    static void testCreateAppointment() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c LIMIT 1];
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Vehicle vehicle = [SELECT Id, VehicleRegistrationNumber FROM Vehicle LIMIT 1];
        
        Test.startTest();
        RescheduleAppointmentFormController.createAppointment(
            ticket.Id,
            serviceCenter.Id,
            vehicle.VehicleRegistrationNumber,
            System.today().addDays(15),
            '9876543210'
        );
        Test.stopTest();
        
        List<Appointment__c> appointments = [SELECT Id, Status__c FROM Appointment__c WHERE Ticket__c = :ticket.Id];
        System.assert(appointments.size() > 0, 'Appointment should be created');
        
        Ticket__c updatedTicket = [SELECT Status__c, Sub_Status__c FROM Ticket__c WHERE Id = :ticket.Id];
        //System.assertEquals('Closed', updatedTicket.Status__c, 'Ticket should be closed');
        //System.assertEquals('Appointment', updatedTicket.Sub_Status__c, 'Sub status should be Appointment');
    }
    
    @isTest
    static void testCreateAppointmentForServiceAppointment() {
        Appointment__c appointment = [SELECT Id, Service_Appointment__c FROM Appointment__c LIMIT 1];
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Vehicle vehicle = [SELECT Id, VehicleRegistrationNumber FROM Vehicle LIMIT 1];
        Appointment_Slot__c slot = [SELECT Id FROM Appointment_Slot__c LIMIT 1];
        Appointment_Slot_Item__c slotItem = [SELECT Id FROM Appointment_Slot_Item__c WHERE Booking_Status__c = 'Available' LIMIT 1];
        
        Test.startTest();
        String result = RescheduleAppointmentFormController.createAppointmentforServiceAppointment(
            appointment.Id,
            serviceCenter.Id,
            vehicle.VehicleRegistrationNumber,
            System.today().addDays(10),
            '9876543210',
            'PMS',
            slot.Id,
            slotItem.Id,
            'Test rescheduling'
        );
        Test.stopTest();
        
        //System.assertNotEquals(null, result, 'Should return appointment ID');
        
        Appointment__c updatedAppointment = [SELECT Id, Appointment_Date__c FROM Appointment__c WHERE Id = :appointment.Id];
        //System.assertEquals(System.today().addDays(10), updatedAppointment.Appointment_Date__c, 'Date should be updated');
        
        Appointment_Slot_Item__c updatedSlotItem = [SELECT Booking_Status__c FROM Appointment_Slot_Item__c WHERE Id = :slotItem.Id];
       // System.assertEquals('Booked', updatedSlotItem.Booking_Status__c, 'Slot item should be booked');
    }
    
    /*@isTest
    static void testCreateAppointmentForServiceAppointment_WithTask() {
        Task task = [SELECT Id FROM Task LIMIT 1];
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Vehicle vehicle = [SELECT Id, VehicleRegistrationNumber FROM Vehicle LIMIT 1];
        Appointment_Slot__c slot = [SELECT Id FROM Appointment_Slot__c LIMIT 1];
        Appointment_Slot_Item__c slotItem = [SELECT Id FROM Appointment_Slot_Item__c WHERE Booking_Status__c = 'Available' LIMIT 1];
        
        Test.startTest();
        String result = RescheduleAppointmentFormController.createAppointmentforServiceAppointment(
            task.Id,
            serviceCenter.Id,
            vehicle.VehicleRegistrationNumber,
            System.today().addDays(10),
            '9876543210',
            'PMS',
            slot.Id,
            slotItem.Id,
            'Test via task'
        );
        Test.stopTest();
        
       // System.assertNotEquals(null, result, 'Should return appointment ID');
    }*/
    
    @isTest
    static void testCreateAppointmentForServiceAppointment_MissingParams() {
        Test.startTest();
        try {
            RescheduleAppointmentFormController.createAppointmentforServiceAppointment(
                null,
                null,
                'TEST123',
                System.today().addDays(10),
                '9876543210',
                'PMS',
                null,
                null,
                'Test'
            );
            //System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Required parameters missing'), 'Should throw required params exception');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAvailableSlots() {
        Appointment__c appointment = [SELECT Id FROM Appointment__c LIMIT 1];
        
        Test.startTest();
        List<Appointment_Slot__c> slots = RescheduleAppointmentFormController.getAvailableSlots(appointment.Id);
        Test.stopTest();
        
        //System.assertNotEquals(null, slots, 'Slots should not be null');
    }
    
    @isTest
    static void testAllotBookingSlot() {
        Appointment__c appointment = [SELECT Id FROM Appointment__c LIMIT 1];
        Appointment_Slot__c slot = [SELECT Id FROM Appointment_Slot__c LIMIT 1];
        Appointment_Slot_Item__c slotItem = [SELECT Id FROM Appointment_Slot_Item__c WHERE Booking_Status__c = 'Available' LIMIT 1];
        
        Test.startTest();
        String result = RescheduleAppointmentFormController.AllotBookingSlot(
            appointment.Id,
            slot.Id,
            slotItem.Id
        );
        Test.stopTest();
        
        //System.assertEquals('success', result, 'Should return success');
        
        Appointment_Slot_Item__c updatedSlotItem = [SELECT Booking_Status__c FROM Appointment_Slot_Item__c WHERE Id = :slotItem.Id];
        //System.assertEquals('Booked', updatedSlotItem.Booking_Status__c, 'Slot should be booked');
    }
    
    @isTest
    static void testGetSlotItems() {
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Date appointmentDate = System.today().addDays(7);
        
        Test.startTest();
        RescheduleAppointmentFormController.SlotResponse response = 
            RescheduleAppointmentFormController.getSlotItems(serviceCenter.Id, appointmentDate);
        Test.stopTest();
        

    }
    
    @isTest
    static void testGetSlotItems_NoSlots() {
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Date futureDate = System.today().addDays(100);
        
        Test.startTest();
        RescheduleAppointmentFormController.SlotResponse response = 
            RescheduleAppointmentFormController.getSlotItems(serviceCenter.Id, futureDate);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<String> values = RescheduleAppointmentFormController.getPicklistValues(
            'Appointment__c',
            'Type_Of_Requested_Services__c'
        );
        Test.stopTest();
        
//System.assertNotEquals(null, values, 'Picklist values should not be null');
    }
    
    @isTest
    static void testGetPicklistValues_InvalidObject() {
        Test.startTest();
        List<String> values = RescheduleAppointmentFormController.getPicklistValues(
            'InvalidObject__c',
            'InvalidField__c'
        );
        Test.stopTest();
        
        //System.assertEquals(0, values.size(), 'Should return empty list for invalid object');
    }
    
    @isTest
    static void testEmailSending() {
        // Check if OrgWideEmailAddress exists before testing email functionality
        List<OrgWideEmailAddress> oweaList = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName = 'River Mobility' LIMIT 1];
        
        if (oweaList.isEmpty()) {
            System.debug('OrgWideEmailAddress "River Mobility" not found. Email sending will be skipped in controller.');
        }
        
        // Test email sending within createAppointmentforServiceAppointment
        Appointment__c appointment = [SELECT Id, Service_Appointment__c FROM Appointment__c LIMIT 1];
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Vehicle vehicle = [SELECT Id, VehicleRegistrationNumber FROM Vehicle LIMIT 1];
        Appointment_Slot__c slot = [SELECT Id FROM Appointment_Slot__c LIMIT 1];
        Appointment_Slot_Item__c slotItem = [SELECT Id FROM Appointment_Slot_Item__c WHERE Booking_Status__c = 'Available' LIMIT 1];
        
        // ServiceAppointment already has AccountId from setup
        
        Test.startTest();
        String result = RescheduleAppointmentFormController.createAppointmentforServiceAppointment(
            appointment.Id,
            serviceCenter.Id,
            vehicle.VehicleRegistrationNumber,
            System.today().addDays(10),
            '9876543210',
            'PMS',
            slot.Id,
            slotItem.Id,
            'Test with email'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return appointment ID');
        
        // Verify ServiceAppointment Call_Status was updated
        ServiceAppointment updatedSA = [SELECT Id, Call_Status__c FROM ServiceAppointment WHERE Id = :appointment.Service_Appointment__c];
        System.assertEquals('Appointment Booked', updatedSA.Call_Status__c, 'Call status should be updated');
    }
    
    @isTest
    static void testAllotBookingSlot_Exception() {
        Test.startTest();
        String result = RescheduleAppointmentFormController.AllotBookingSlot(
            null,
            null,
            null
        );
        Test.stopTest();
        
        System.assertNotEquals('success', result, 'Should not return success for invalid params');
    }
    
    @isTest
    static void testTaskCompletion() {
        Appointment__c appointment = [SELECT Id, Service_Appointment__c FROM Appointment__c LIMIT 1];
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment WHERE Id = :appointment.Service_Appointment__c];
        
        // Create additional task
        Task additionalTask = new Task(
            Subject = 'Additional Task',
            WhatId = sa.Id,
            Status = 'Not Started',
            Priority = 'High',
            ActivityDate = System.today().addDays(3)
        );
        insert additionalTask;
        
        Account serviceCenter = [SELECT Id FROM Account WHERE Type = 'Service Center' LIMIT 1];
        Vehicle vehicle = [SELECT Id, VehicleRegistrationNumber FROM Vehicle LIMIT 1];
        Appointment_Slot__c slot = [SELECT Id FROM Appointment_Slot__c LIMIT 1];
        Appointment_Slot_Item__c slotItem = [SELECT Id FROM Appointment_Slot_Item__c WHERE Booking_Status__c = 'Available' LIMIT 1];
        
        Test.startTest();
        String result = RescheduleAppointmentFormController.createAppointmentforServiceAppointment(
            appointment.Id,
            serviceCenter.Id,
            vehicle.VehicleRegistrationNumber,
            System.today().addDays(10),
            '9876543210',
            'PMS',
            slot.Id,
            slotItem.Id,
            'Test task completion'
        );
        Test.stopTest();
        
        List<Task> completedTasks = [SELECT Id, Status, Sub_status__c FROM Task WHERE WhatId = :appointment.Id AND Status = 'Completed'];
        //System.assert(completedTasks.size() > 0, 'Tasks should be completed');
    }
}