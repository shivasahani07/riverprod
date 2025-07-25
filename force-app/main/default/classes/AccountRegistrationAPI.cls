@RestResource(urlMapping='/RegisterAccount')
global with sharing class AccountRegistrationAPI {
    
    @HttpPost
    global static void createAccountContact() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        Map<String, String> response = new Map<String, String>();
        
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        System.debug('🔵 Raw Request Body: ' + requestBody);
        
        Map<String, Object> requestMap = (Map<String, Object>)JSON.deserializeUntyped(requestBody);
        System.debug('🟢 Deserialized Request Map: ' + requestMap);
        Map<String, Object> billing_address = (Map<String, Object>)requestMap.get('billing_address') != null? (Map<String, Object>)requestMap.get('billing_address'):null;
        Map<String, Object> shipping_address = (Map<String, Object>)requestMap.get('shipping_address') != null? (Map<String, Object>)requestMap.get('shipping_address'):null;
        
        String leadEmail = (String)requestMap.get('email_address') != null? (String)requestMap.get('email_address'): '';
        String phone = (String)requestMap.get('phone_number') != null?(String)requestMap.get('phone_number'):'';
        String Company = (String)requestMap.get('full_name');
        String accountId = null;
        List<lead> existingLead = new List<lead>();
        List<Account> existingAccount = new List<Account>();
        String dealerCode = (String) requestMap.get('DealerCode'); 
        System.debug('dealer Code '+dealerCode);
        try{
            
            If(phone != '')
                existingAccount = [SELECT Id FROM Account WHERE Phone = :phone  LIMIT 1];
            
            If(existingAccount.isEmpty()){ 
                existingLead = [SELECT Id,Owner.Type,Is_Order_Created__c,postalCode FROM Lead 
                                WHERE (Email = :leadEmail OR Phone = :phone) 
                                AND isConverted = false 
                                LIMIT 1];
                
                
                if (!existingLead.isEmpty()) {
                    system.debug('existing lead found>>'+existingLead[0]);
                    if (existingLead[0].Owner.Type == 'Queue') {
                    //     User targetUser = [SELECT Id,LastName FROM User WHERE LastName LIKE '%@store' LIMIT 1];
                        
                    //     if (targetUser != null) {
                    //         existingLead[0].OwnerId = targetUser.Id;
                    String preferredStoreId = LeadTriggerHandler.getPreferredStoreByPincode(existingLead[0].postalCode); // ← you provide this logic
                    if (preferredStoreId != null) {
                        System.debug('Assigning preferred store: ' + preferredStoreId);
                        existingLead[0].Dealer_Code__c = preferredStoreId;
                        existingLead[0].Dealer_Allocation__c = true;
                    }

                            existingLead[0].Is_Order_Created__c = true;
                            update existingLead[0];
                    //     }
                    }
                    
                    Database.LeadConvert lc = new Database.LeadConvert();
                    lc.setLeadId(existingLead[0].Id);
                    lc.setConvertedStatus('Converted');
                    lc.setDoNotCreateOpportunity(true);
                    
                    Database.LeadConvertResult lcr = Database.convertLead(lc);
                    
                    if (lcr.isSuccess()) {
                        system.debug('Lead converted to Account and Contact' + lcr.getAccountId() + ' contact is >> ' + lcr.getContactId());
                        Id newContactId = lcr.getContactId();
                        
                        // Set the custom field Primary_Contact__c to true on the Contact
                        //Contact newContact = new Contact(Id = newContactId, Primary_Contact__c = true);
                        //update newContact;
                        
                        Account newAccount = new Account(Id = lcr.getAccountId(),
                                                         Type = 'Customer',
                                                         Name = (String)requestMap.get('full_name'),
                                                         Phone = (String)requestMap.get('phone_number') != null ? (String)requestMap.get('phone_number') : '',
                                                         Email__c = (String)requestMap.get('email_address') != null ? (String)requestMap.get('email_address') : '',
                                                         BillingCountry = (String)billing_address.get('country') != null ? (String)billing_address.get('country') : 'India',
                                                         BillingStreet = ((String)billing_address.get('address_1') != null ? (String)billing_address.get('address_1') : '') +' '+ ((String)billing_address.get('address_2') != null ? (String)billing_address.get('address_2') : ''),
                                                         BillingCity = (String)billing_address.get('city') != null ? (String)billing_address.get('city') : '',
                                                         BillingState = (String)billing_address.get('state') != null ? (String)billing_address.get('state') : '',
                                                         BillingPostalCode = (String)billing_address.get('pin_code') != null ? (String)billing_address.get('pin_code') : '',
                                                         ShippingCountry = (String)shipping_address.get('country') != null ? (String)shipping_address.get('country') : 'India',
                                                         ShippingStreet = ((String)shipping_address.get('address_1') != null ? (String)shipping_address.get('address_1') : '')+ ' '+((String)shipping_address.get('address_2') != null ? (String)shipping_address.get('address_2') : ''),
                                                         ShippingCity = (String)shipping_address.get('city') != null ? (String)shipping_address.get('city') : '',
                                                         ShippingState = (String)shipping_address.get('state') != null ? (String)shipping_address.get('state') : '',
                                                         ShippingPostalCode = (String)shipping_address.get('pin_code') != null ? (String)shipping_address.get('pin_code') : ''
                                                        );
                        update newAccount;
                        
                        accountId = lcr.getAccountId();
                    } else {
                        system.debug('error occurred >> ' + lcr);
                    }
                } else {
                    
                    
                    Lead newLead = new Lead(
                        LastName = (String)requestMap.get('full_name'),
                        Company =(String)requestMap.get('full_name'),
                        Email = (String)requestMap.get('email_address') != null ? (String)requestMap.get('email_address') : '',
                        Phone = (String)requestMap.get('phone_number') != null ? (String)requestMap.get('phone_number') : '',
                        LeadSource	= 'River Website',
                        Is_Order_Created__c = true,
                        Status = 'Converted',
                        Street = (billing_address.containsKey('address_1') ? (String)billing_address.get('address_1') : '') + ' ' +(billing_address.containsKey('address_2') ? (String)billing_address.get('address_2') : ''),
                        City = billing_address.containsKey('city') ? (String)billing_address.get('city') : '',
                        State = billing_address.containsKey('state') ? (String)billing_address.get('state') : '',
                        PostalCode = billing_address.containsKey('pin_code') ? (String)billing_address.get('pin_code') : '',
                        Country = billing_address.containsKey('country') ? (String)billing_address.get('country') : 'India'
                        /* Address = new Address(
                        street = ((String)billing_address.get('address_1') != null ? (String)billing_address.get('address_1') : '') + ' ' + ((String)billing_address.get('address_2') != null ? (String)billing_address.get('address_2') : ''),
                        city = (String)billing_address.get('city') != null ? (String)billing_address.get('city') : '',
                        state = (String)billing_address.get('state') != null ? (String)billing_address.get('state') : '',
                        postalCode = (String)billing_address.get('pin_code') != null ? (String)billing_address.get('pin_code') : '',
                        country = (String)billing_address.get('country') != null ? (String)billing_address.get('country') : 'India'
                        )*/
                    );
                    insert newLead;
                    
                    // if (newLead.Owner.Type == 'Queue') {
                    //     User targetUser = [SELECT Id,LastName FROM User WHERE LastName LIKE '%@store' LIMIT 1];
                        
                    //     if (targetUser != null) {
                            // newLead.OwnerId = targetUser.Id;
                            // update newLead; 
                    //     }
                    // }
                    
                    Database.LeadConvert lc = new Database.LeadConvert();
                    lc.setLeadId(newLead.Id);
                    lc.setConvertedStatus('Converted');
                    
                    Database.LeadConvertResult lcr = Database.convertLead(lc);
                    system.debug('New Lead is created >> ' + newLead);                    system.debug('creating new account and contact1');
                    Account newAccount = new Account(
                        Id = lcr.getAccountId(),
                        Name = (String)requestMap.get('full_name'),
                        AccountSource = 'River Website',
                        Type = 'Customer',
                        Email__c = (String)requestMap.get('email_address') != null ? (String)requestMap.get('email_address') : '',
                        BillingCountry = (String)billing_address.get('country') != null ? (String)billing_address.get('country') : 'India',
                        Phone = (String)requestMap.get('phone_number') != null ? (String)requestMap.get('phone_number') : '',
                        BillingStreet = ((String)billing_address.get('address_1') != null ? (String)billing_address.get('address_1') : '') +' '+((String)billing_address.get('address_2') != null ? (String)billing_address.get('address_2') : ''),
                        BillingCity = (String)billing_address.get('city') != null ? (String)billing_address.get('city') : '',
                        BillingState = (String)billing_address.get('state') != null ? (String)billing_address.get('state') : '',
                        BillingPostalCode = (String)billing_address.get('pin_code') != null ? (String)billing_address.get('pin_code') : '',
                        ShippingCountry = (String)shipping_address.get('country') != null ? (String)shipping_address.get('country') : 'India',
                        ShippingStreet = ((String)shipping_address.get('address_1') != null ? (String)shipping_address.get('address_1') : '') +' '+ ((String)shipping_address.get('address_2') != null ? (String)shipping_address.get('address_2') : ''),
                        ShippingCity = (String)shipping_address.get('city') != null ? (String)shipping_address.get('city') : '',
                        ShippingState = (String)shipping_address.get('state') != null ? (String)shipping_address.get('state') : '',
                        ShippingPostalCode = (String)shipping_address.get('pin_code') != null ? (String)shipping_address.get('pin_code') : ''
                    );
                    update newAccount;
                    
                    
                    accountId = newAccount.Id;
                }
            }
            Else{
                // Create a new Lead with Status as 'Converted'
                /* Lead newLead = new Lead(
                LastName = (String)requestMap.get('full_name'),
                Company = (String)requestMap.get('full_name'),
                Email = (String)requestMap.get('email_address') != null ? (String)requestMap.get('email_address') : '',
                Phone = (String)requestMap.get('phone_number') != null ? (String)requestMap.get('phone_number') : '',
                Status = 'Converted' // Ensure 'Converted' is a valid picklist value in your org
                /* Address = new Address(
                street = ((String)billing_address.get('address_1') != null ? (String)billing_address.get('address_1') : '') + ' ' + ((String)billing_address.get('address_2') != null ? (String)billing_address.get('address_2') : ''),
                city = (String)billing_address.get('city') != null ? (String)billing_address.get('city') : '',
                state = (String)billing_address.get('state') != null ? (String)billing_address.get('state') : '',
                postalCode = (String)billing_address.get('pin_code') != null ? (String)billing_address.get('pin_code') : '',
                country = (String)billing_address.get('country') != null ? (String)billing_address.get('country') : 'India'
                )
                );
                insert newLead;*/
                
                accountId = existingAccount[0].Id;
                
                Account newAccount = new Account(
                    id = accountId,
                    Name = (String)requestMap.get('full_name'),
                    Type = 'Customer',
                    Email__c = (String)requestMap.get('email_address') != null ? (String)requestMap.get('email_address') : '',
                    BillingCountry = (String)billing_address.get('country') != null ? (String)billing_address.get('country') : 'India',
                    Phone = (String)requestMap.get('phone_number') != null ? (String)requestMap.get('phone_number') : '',
                    BillingStreet = ((String)billing_address.get('address_1') != null ? (String)billing_address.get('address_1') : '') +' '+((String)billing_address.get('address_2') != null ? (String)billing_address.get('address_2') : ''),
                    BillingCity = (String)billing_address.get('city') != null ? (String)billing_address.get('city') : '',
                    BillingState = (String)billing_address.get('state') != null ? (String)billing_address.get('state') : '',
                    BillingPostalCode = (String)billing_address.get('pin_code') != null ? (String)billing_address.get('pin_code') : '',
                    ShippingCountry = (String)billing_address.get('country') != null ? (String)billing_address.get('country') : 'India',
                    ShippingStreet = ((String)shipping_address.get('address_1') != null ? (String)shipping_address.get('address_1') : '') +' '+ ((String)shipping_address.get('address_2') != null ? (String)shipping_address.get('address_2') : ''),
                    ShippingCity = (String)shipping_address.get('city') != null ? (String)shipping_address.get('city') : '',
                    ShippingState = (String)shipping_address.get('state') != null ? (String)shipping_address.get('state') : '',
                    ShippingPostalCode = (String)shipping_address.get('pin_code') != null ? (String)shipping_address.get('pin_code') : ''
                );
                Update newAccount;
            }
            
            response.put('status', 'Success');
            
            response.put('accountId', accountId);
            res.statusCode = 200; 
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            
            Integration_Log__c  logObj = new Integration_Log__c(
                Integration_Type__c = 'Account Registration',
                Request_Payload__c = JSON.seriaLizePretty(requestMap),
                Response_Payload__c = JSON.seriaLizePretty(response),
                Status__c = 'Success'
            );
            Insert logObj;
            system.debug('Log created>>'+logObj);
        }
        catch(exception e){
            
            system.debug('Exception occured: '+e);
            response.put('status', 'Failed');
            res.statusCode = 500; 
            res.responseBody = Blob.valueOf('Exception: '+e.getMessage());
            
            Integration_Log__c  logObj = new Integration_Log__c(
                Integration_Type__c = 'Account Registration',
                Request_Payload__c = JSON.seriaLizePretty(requestMap),
                Response_Payload__c = JSON.seriaLizePretty(res),
                Error_Messages__c = 'Exception: '+e.getMessage(),
                Status__c = 'Failed'
            );
            Insert logObj;
            system.debug('Log created exception>>'+logObj);
            
        }
    }
    
    Global class CommonException extends Exception {}
}