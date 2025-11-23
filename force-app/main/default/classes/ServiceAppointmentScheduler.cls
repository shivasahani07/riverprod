/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-14-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
global without sharing class ServiceAppointmentScheduler implements Database.Batchable<sObject>, Schedulable {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        //Date targetDate = System.today().addDays(20);
        // Query tentative milestones within next 20 days that have a vehicle
        /*return Database.getQueryLocator([
            SELECT Id, Name, MilestoneDate, Stage, AssetId, VehicleId,
                   Vehicle.Dealer__c, Vehicle.CurrentOwnerId,Is_Scheduled__c 
            FROM AssetMilestone
            WHERE MilestoneDate != NULL
              AND MilestoneDate > TODAY
              AND MilestoneDate <= :targetDate
              AND Stage = 'Tentative'
              AND VehicleId != NULL AND Is_Scheduled__c = True
        ]);*/
        
       Integer daysOffset = Integer.valueOf(System.Label.AssetMilestoneDaysOffset);
 
   
    Date targetDate = System.today().addDays(daysOffset);
 
   
    String query = System.Label.AssetMilestoneQuery;
 
    
    query = query.replace('TARGET_DATE_PLACEHOLDER', String.valueOf(targetDate));
 
    System.debug('Final Query: ' + query);
 
    return Database.getQueryLocator(query);
         
    }
     global void execute(Database.BatchableContext bc, List<AssetMilestone> scope) {

        Integer saSuccess = 0;
        Integer saFailed = 0;
        List<String> saErrors = new List<String>();

        Integer taskSuccess = 0;
        Integer taskFailed = 0;
        List<String> taskErrors = new List<String>();

        if (scope == null || scope.isEmpty()) return;

        try {
            // Prepare lists & sets
            List<ServiceAppointment> appointmentsToInsert = new List<ServiceAppointment>();
            List<AssetMilestone> updateAssetMilestone = new List<AssetMilestone>();
            Set<Id> vehicleIds = new Set<Id>();

            // Build ServiceAppointment records from milestones
            for (AssetMilestone milestone : scope) {
                if (milestone.VehicleId == null) continue;
                milestone.Is_Scheduled__c = True;
                updateAssetMilestone.add(milestone);
                ServiceAppointment sa = new ServiceAppointment();
                sa.Subject = 'Service Appointment for Milestone: ' + (milestone.Name == null ? '' : milestone.Name);
                sa.Appointment_Date__c = milestone.MilestoneDate;
                sa.Asset_Milestone__c = milestone.Id;
                sa.EarliestStartTime = DateTime.newInstance(milestone.MilestoneDate, Time.newInstance(0, 0, 0, 0));
                sa.DueDate = milestone.MilestoneDate;
                sa.Description = 'Auto-created Service Appointment for milestone ' + (milestone.Name == null ? '' : milestone.Name);
                sa.Vehicle__c = milestone.VehicleId;
                sa.Call_Status__c = 'Pending';

                // Prefer Vehicle.Dealer__c as service center (grabbed from relationship in start query)
                // if relationship not present (defensive), leave null
                if (milestone.Vehicle != null) {
                    sa.Service_Centre__c = milestone.Vehicle.Dealer__c;
                    sa.ParentRecordId = milestone.Vehicle.CurrentOwnerId;
                }

                appointmentsToInsert.add(sa);
                vehicleIds.add(milestone.VehicleId);
            }
            if(!updateAssetMilestone.isEmpty()){
                update updateAssetMilestone;
            }

            if (appointmentsToInsert.isEmpty()) return;

            // Insert ServiceAppointments

            if(!appointmentsToInsert.isEmpty()){
               Database.SaveResult[] saResults = Database.insert(appointmentsToInsert, false);

                for (Integer i = 0; i < saResults.size(); i++) {
                    if (saResults[i].isSuccess()) {
                        saSuccess++;
                    } else {
                        saFailed++;
                        for (Database.Error err : saResults[i].getErrors()) {
                            saErrors.add(
                                'ServiceAppointment Error - MilestoneId: ' 
                                + scope[i].Id + ' - ' + err.getMessage()
                            );
                        }
                    }
                }
            }
             

            // Collect SA ids and vehicles
            Set<Id> saIds = new Set<Id>();
            for (ServiceAppointment sa : appointmentsToInsert) {
                if (sa.Id != null) saIds.add(sa.Id);
            }

            // ---------------- Bulk queries ----------------

            // 1) Fetch Vehicles (Dealer__c + contact info)
            Map<Id, Vehicle> vehicleById = new Map<Id, Vehicle>();
            if (!vehicleIds.isEmpty()) {
                for (Vehicle v : [
                    SELECT Id, Dealer__c, CurrentOwnerId, CurrentOwner.Phone, CurrentOwner.Email__c
                    FROM Vehicle
                    WHERE Id IN :vehicleIds
                ]) {
                    vehicleById.put(v.Id, v);
                }
            }

            // 2) Fetch recent completed WorkOrders (job cards) for these vehicles
            //    Keep first (most recent) per vehicle.
            Map<Id, WorkOrder> recentWorkOrderByVehicle = new Map<Id, WorkOrder>();
            if (!vehicleIds.isEmpty()) {
                List<WorkOrder> wos = [
                    SELECT Id, Vehicle__c, Asset_Milestone__c, Service_Center__c, OwnerId, CreatedDate
                    FROM WorkOrder
                    WHERE Vehicle__c IN :vehicleIds
                      AND Status = 'Completed'
                    ORDER BY CreatedDate DESC
                    LIMIT 10000
                ];
                for (WorkOrder wo : wos) {
                    if (wo.Vehicle__c != null && !recentWorkOrderByVehicle.containsKey(wo.Vehicle__c)) {
                        recentWorkOrderByVehicle.put(wo.Vehicle__c, wo);
                    }
                }
            }

            // 3) Determine account IDs to search for CRE contacts:
            //    For each vehicle: if recent WorkOrder -> use wo.Service_Center__c
            //                     else use vehicle.Dealer__c
            Map<Id, Id> vehicleToAccountForOwner = new Map<Id, Id>();
            Set<Id> serviceCenterAccountIds = new Set<Id>();
            for (Id vehId : vehicleIds) {
                WorkOrder wo = recentWorkOrderByVehicle.get(vehId);
                if (wo != null && wo.Service_Center__c != null) {
                    vehicleToAccountForOwner.put(vehId, wo.Service_Center__c);
                    serviceCenterAccountIds.add(wo.Service_Center__c);
                } else {
                    Vehicle v = vehicleById.get(vehId);
                    if (v != null && v.Dealer__c != null) {
                        vehicleToAccountForOwner.put(vehId, v.Dealer__c);
                        serviceCenterAccountIds.add(v.Dealer__c);
                    }
                }
            }

            // 4) Query CRE Contacts under those accounts
            Map<Id, List<Contact>> creContactsByAccount = new Map<Id, List<Contact>>();
            Set<Id> creContactIds = new Set<Id>();
            if (!serviceCenterAccountIds.isEmpty()) {
                for (Contact c : [
                    SELECT Id, AccountId, Name, Email, Phone, Designation__c
                    FROM Contact
                    WHERE AccountId IN :serviceCenterAccountIds
                      AND Designation__c = 'CRE'
                ]) {
                    if (!creContactsByAccount.containsKey(c.AccountId)) creContactsByAccount.put(c.AccountId, new List<Contact>());
                    creContactsByAccount.get(c.AccountId).add(c);
                    creContactIds.add(c.Id);
                }
            }

            // 5) Query Users linked to those CRE Contacts (active users)
            Map<Id, List<User>> creUsersByAccount = new Map<Id, List<User>>();
            if (!creContactIds.isEmpty()) {
                for (User u : [
                    SELECT Id, ContactId, Contact.AccountId, IsActive
                    FROM User
                    WHERE ContactId IN :creContactIds
                      AND IsActive = TRUE
                ]) {
                    Id acctId = (u.Contact != null) ? u.Contact.AccountId : null;
                    if (acctId != null) {
                        if (!creUsersByAccount.containsKey(acctId)) creUsersByAccount.put(acctId, new List<User>());
                        creUsersByAccount.get(acctId).add(u);
                    }
                }
            }

            // 6) Query created ServiceAppointments to get data for task creation
            List<ServiceAppointment> saList = new List<ServiceAppointment>();
            if (!saIds.isEmpty()) {
                saList = [
                    SELECT Id, AppointmentNumber, Service_Centre__c, Appointment_Date__c, Asset_Milestone__r.Name,
                           Vehicle__c, ParentRecordId,
                           Vehicle__r.CurrentOwnerId, Vehicle__r.CurrentOwner.Phone, Vehicle__r.CurrentOwner.Email__c
                    FROM ServiceAppointment
                    WHERE Id IN :saIds
                ];
            }

            // 7) Get Task record type for 'Task_Reminder' if exists
            Id taskRecordTypeId = null;
            try {
                RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Task' AND DeveloperName = 'Task_Reminder' LIMIT 1];
                taskRecordTypeId = rt.Id;
            } catch (Exception ex) {
                // ignore - we'll not set RecordTypeId if not found
                taskRecordTypeId = null;
            }

            // 8) Build Tasks
            List<Task> tasksToInsert = new List<Task>();
            for (ServiceAppointment saRec : saList) {
                Task t = new Task();
                t.Subject = (saRec.AppointmentNumber == null ? '' : saRec.AppointmentNumber) + '- Call_N10';
                t.WhatId = saRec.Id;
                if (saRec.Appointment_Date__c != null) {
                    // safe: activity date 10 days prior
                    t.ActivityDate = saRec.Appointment_Date__c.addDays(-10);
                }
                t.Customer__c = (saRec.Vehicle__r == null) ? null : saRec.Vehicle__r.CurrentOwnerId;
                // Phone/Email - defensive null checks
                t.Phone_number__c = (saRec.Vehicle__r == null) ? null : saRec.Vehicle__r.CurrentOwner.Phone;
                t.Customer_Email__c = (saRec.Vehicle__r != null && saRec.Vehicle__r.CurrentOwner != null && String.isNotBlank(saRec.Vehicle__r.CurrentOwner.Email__c))
                    ? saRec.Vehicle__r.CurrentOwner.Email__c : null;
                t.Appointment_Date__c = saRec.Appointment_Date__c;
                if (taskRecordTypeId != null) t.RecordTypeId = taskRecordTypeId;
                t.Vehicle__c = saRec.Vehicle__c;
                t.Status = 'Not Started';
                t.Priority = 'High';
                t.Service_Name__c = (saRec.Asset_Milestone__r == null) ? null : saRec.Asset_Milestone__r.Name;

                // Determine owner account for this vehicle
                Id ownerAccountId = vehicleToAccountForOwner.get(saRec.Vehicle__c);
                Id ownerUserId = null;

                // Prefer CRE User under ownerAccountId
                if (ownerAccountId != null && creUsersByAccount.containsKey(ownerAccountId) && !creUsersByAccount.get(ownerAccountId).isEmpty()) {
                    // pick the first active user for now (could be changed to round-robin)
                    ownerUserId = creUsersByAccount.get(ownerAccountId)[0].Id;
                } else {
                    // No CRE user found - fallback
                    // If we had a recent workorder for the vehicle, use its OwnerId as fallback owner
                    WorkOrder recentWO = recentWorkOrderByVehicle.get(saRec.Vehicle__c);
                    if (recentWO != null && recentWO.OwnerId != null) {
                        ownerUserId = recentWO.OwnerId;
                    } else {
                        // final fallback: try to use any user mapped via contact -> (if some mapping logic exists)
                        // We don't have a separate "mapAccountOnUser" here; so leave ownerUserId null (system default)
                        ownerUserId = null;
                    }
                }

                if (ownerUserId != null) {
                    t.OwnerId = ownerUserId;
                }

                tasksToInsert.add(t);
            }

            // Insert tasks if any
            if (!tasksToInsert.isEmpty()) {
                Database.SaveResult[] taskResults = Database.insert(tasksToInsert, false);

                for (Integer i = 0; i < taskResults.size(); i++) {
                    if (taskResults[i].isSuccess()) {
                        taskSuccess++;
                    } else {
                        taskFailed++;
                        for (Database.Error err : taskResults[i].getErrors()) {
                            taskErrors.add(
                                'Task Error - Index: ' + i + ' - ' + err.getMessage()
                            );
                        }
                    }
                }
}

           List<String> allErrors = new List<String>();
            allErrors.addAll(saErrors);
            allErrors.addAll(taskErrors);


             Service_Appointment_Log__c log = new Service_Appointment_Log__c();
            log.Name = String.valueof(Date.Today()) + '-'+'Service Appintment Scheduler';
            log.Total__c = saSuccess;
            log.Total_ServiceAppointmens_Failed__c = saFailed;
            log.Total_Tasks_Success__c = taskSuccess;
            log.Total_Tasks_Failed__c = taskFailed;
            log.Errors__c = log.Errors__c = allErrors.isEmpty()? 'No Errors': String.join(allErrors, '\n');

            insert log;


        } catch (Exception e) {
            System.debug('ServiceAppointmentScheduler Error: ' + e.getMessage() + ' Line: ' + e.getLineNumber());
            // swallow or rethrow depending on your preference
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('ServiceAppointmentScheduler finished.');
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ServiceAppointmentScheduler(), 50);
    }
}