@RestResource(urlMapping='/createLeadRiverWebsite')  
global class LeadCreationFromRiverWebsite {
    
    @HttpPost  
    global static string createLeadFromWebsite() {  
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;  
        
        // Parse the request body  
        String requestBody = req.requestBody.toString(); 
        System.debug('requestBody == >'+requestBody);
        Map<String, Object> requestBodyMap = (Map<String, Object>) JSON.deserializeUntyped(requestBody);  
        
        String fullName = (String) requestBodyMap.get('FullName');  
        String company = (String) requestBodyMap.get('Company');  
        String email = (String) requestBodyMap.get('Email');  
        String phone = (String) requestBodyMap.get('Phone');  
        String city = (String) requestBodyMap.get('City');  
        String postalCode = String.valueOf(requestBodyMap.get('PostalCode'));  
        Boolean homeTestRide = (Boolean) requestBodyMap.get('HomeTestRide');  
        Boolean instoreTestdrive = (Boolean) requestBodyMap.get('InstoreTestdrive');
        String utm_source = (String) requestBodyMap.get('utm_source'); 
        Boolean verified = (Boolean) requestBodyMap.get('verified');  
 
        // Retrieve date/time values from the request body  
        String startDateTimeStr = (String) requestBodyMap.get('startDateTimeStr');  
        String endDateTimeStr = (String) requestBodyMap.get('endDateTimeStr');  

        // Initialize Datetime variables  
        Datetime startDateTime;  
        Datetime endDateTime;  

        // Convert to Datetime if values are provided  
        if (startDateTimeStr != null) {  
            startDateTime = Datetime.valueOf(startDateTimeStr);  
        } else {  
            startDateTime = null; 
        }  

        if (endDateTimeStr != null) {  
            endDateTime = Datetime.valueOf(endDateTimeStr);  
        } else {  
            endDateTime = null; 
        }  

        String dealerCode = (String) requestBodyMap.get('DealerCode');  
        
        

        // Query for existing lead based on phone number  
        List<Lead> leads = [SELECT Id, LastName, Company, Email, Phone, City,   
                            Test_ride_Start_date__c, Test_ride_end_date__c,   
                            Dealer_Code__c, Home_Test_Ride__c, Instore_Test_drive__c,Utm_Source__c,Verified__c,Status
                            FROM Lead WHERE Phone = :phone LIMIT 1];  

        Lead leadToUpdate;  
        // Map<String, Id> queueMap = new Map<String, Id>();
        // for (Group grp : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue']) {
        //         queueMap.put(grp.DeveloperName, grp.Id);
        //     }
        //     System.debug('queueMap populated =========>' + queueMap);

        try {
            if (!leads.isEmpty()) {  
                // If a lead is found, update it  
                leadToUpdate = leads[0];  
            } else {  
                // If no lead is found, create a new one  
                leadToUpdate = new Lead();  
               // leadToUpdate.Status = 'Test Ride';
                leadToUpdate.LeadSource = 'River Website';
            }  

            // Update the lead fields  
            leadToUpdate.LastName = fullName;  
            leadToUpdate.Company = fullName;  
            leadToUpdate.Email = email;  
            leadToUpdate.Phone = phone;  
            leadToUpdate.City = city;  
            leadToUpdate.PostalCode = postalCode;  
            leadToUpdate.Test_ride_Start_date__c = startDateTime;  
            leadToUpdate.Test_ride_end_date__c = endDateTime;    
            Account dealerCodeAccount;
            if (String.isNotBlank(dealerCode)) {
                List<Account> dealerAccounts = [SELECT Id, Name FROM Account WHERE Type = 'Dealer' AND Center_Code__c = :dealerCode LIMIT 1
                ];
                if (!dealerAccounts.isEmpty()) {
                    dealerCodeAccount = dealerAccounts[0];
                }
            }
            
            // Fallback to "No Service Available" if no dealer account found
            // if (dealerCodeAccount == null) {
            //     List<Account> fallback = [SELECT Id, Name,Center_Code__c FROM Account WHERE Name = 'No Service Available' LIMIT 1
            //     ];
            //     if (!fallback.isEmpty()) {
            //         dealerCodeAccount = fallback[0];
            //         dealerCode = fallback[0].Center_Code__c;
            //     }
            // }
            //Account dealerCodeAccount = [Select Id,Name from Account where type = 'Dealer' AND Center_Code__c =:dealerCode LIMIT 1];
            //leadToUpdate.Stores_Name__c = dealerCodeAccount != null ? dealerCodeAccount.Name : '';
            leadToUpdate.Dealer_Code__c = dealerCode;
            //leadToUpdate.ownerId = queueMap.get('Head_Quarter'); 
            leadToUpdate.Utm_Source__c = utm_source;
            Boolean isValue;
           
            leadToUpdate.Verified__c = verified;
            leadToUpdate.Home_Test_Ride__c = homeTestRide != null ? homeTestRide : false;  
            leadToUpdate.Instore_Test_drive__c = instoreTestdrive != null ? instoreTestdrive : false;  

            if (leadToUpdate.Id != null) {  
                // Update existing lead  
                update leadToUpdate;  
            } else {  
                // Insert new lead  
                insert leadToUpdate;  
            }
            System.debug('leadToUpdate ===> ' + leadToUpdate);
			
            // Log success
            Integration_Log__c logObj = new Integration_Log__c(
               Integration_Type__c = ' Lead Creation',
                //Integration_Type__c = 'Lead Creation from River Website',
                Request_Payload__c = JSON.serializePretty(requestBodyMap),
                Response_Payload__c = 'Lead processed successfully: ' + leadToUpdate.Id,
                Status__c = 'Success'
            );
            Insert logObj;


            return 'Lead processed successfully: ' + leadToUpdate.Id;

        } catch(Exception e) {
            // Log failure
            Integration_Log__c logObj = new Integration_Log__c(
                
               
                Integration_Type__c = ' Lead Creation',
                //Integration_Type__c = 'Lead Creation from River Website',
                Request_Payload__c = JSON.serializePretty(requestBodyMap),
                Response_Payload__c = 'Error: ' + e.getMessage(),
                Error_Messages__c = 'Exception: ' + e.getMessage(),
                Status__c = 'Failed'
            );
            Insert logObj;
            System.debug('Log created for failed lead creation: ' + logObj);

            return 'Error: ' + e.getMessage();
        }
    }
    
    public class CustomException extends Exception {}
}