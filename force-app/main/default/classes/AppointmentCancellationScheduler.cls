global class AppointmentCancellationScheduler implements Database.Batchable<SObject>, Schedulable {

    // Schedulable entry point
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new AppointmentCancellationScheduler(), 50);
    }

    // Batch start method
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, Appointment_Date__c, Service_Appointment__c, Vehicle__c,
                   Service_Appointment__r.Account.Name,
                   Service_Appointment__r.Account.Email__c,
                   Service_Appointment__r.SchedStartTime
            FROM Appointment__c
            WHERE Status__c NOT IN ('Completed', 'Cancel')
            AND Appointment_Date__c < :Date.today()
        ]);
    }

    // Batch execute method
    global void execute(Database.BatchableContext bc, List<Appointment__c> scope) {
        // Collections
        Set<Id> saIds = new Set<Id>();
        Set<Id> vehicleIds = new Set<Id>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Step 1: Prepare appointment updates and collect related Ids
        for (Appointment__c appt : scope) {
            appt.Status__c = 'Cancel';

            if (appt.Service_Appointment__c != null) {
                saIds.add(appt.Service_Appointment__c);
            } else if (appt.Vehicle__c != null) {
                vehicleIds.add(appt.Vehicle__c);
            }

            // Prepare email if account email is available
            if (appt.Service_Appointment__r.Account.Email__c != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { appt.Service_Appointment__r.Account.Email__c });
                mail.setSubject('Your Service Appointment is Cancelled');

                String body = 'Hey ' + appt.Service_Appointment__r.Account.Name +
                    ',\n\nYour service appointment scheduled for ' + 
                    String.valueOf(appt.Service_Appointment__r.SchedStartTime) + 
                    ' has expired and is now cancelled.' +
                    '\n\nFor more info, please contact our Service Advisor.' +
                    '\n\nThank you.';

                mail.setPlainTextBody(body);
                emails.add(mail);
            }
        }

        // Step 2: Query once outside the loop
        List<ServiceAppointment> serviceApplist = new List<ServiceAppointment>();
        if (!saIds.isEmpty()) {
            serviceApplist = [SELECT Id FROM ServiceAppointment WHERE Id IN :saIds];
            for (ServiceAppointment saRec : serviceApplist) {
                saRec.Call_Status__c = 'NFA';
            }
        }

        // Step 3: Handle vehicle owners (optional email sending logic)
        if (!vehicleIds.isEmpty()) {
            List<Vehicle> vhkls = [SELECT Id, CurrentOwnerId, CurrentOwner.Email__c FROM Vehicle WHERE Id IN :vehicleIds];
            for (Vehicle v : vhkls) {
                if (v.CurrentOwner.Email__c != null) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[] { v.CurrentOwner.Email__c });
                    mail.setSubject('Your Vehicle Service Appointment is Cancelled');
                    mail.setPlainTextBody('Hello, your vehicle\'s scheduled service has been cancelled. Please reschedule at your convenience.');
                    emails.add(mail);
                }
            }
        }

        // Step 4: Set Org-Wide Email Address (do once)
        OrgWideEmailAddress orgWideEmail = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'River Mobility' LIMIT 1];
        for (Messaging.SingleEmailMessage mail : emails) {
            mail.setOrgWideEmailAddressId(orgWideEmail.Id);
        }

        // Step 5: Perform DML operations
        if (!scope.isEmpty()) update scope;
        if (!serviceApplist.isEmpty()) update serviceApplist;
        if (!emails.isEmpty()) Messaging.sendEmail(emails);
    }

    // Batch finish method
    global void finish(Database.BatchableContext bc) {
        System.debug('Batch completed for cancelling expired appointments.');
    }
}