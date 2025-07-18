@isTest
private class CaseTriggerTest {
	@isTest
    static void testCaseTrigger() {
        
        Account acc = new Account(Name = 'Test Account', Email__c = 'test@gmail.com', type='Customer');
        insert acc;
        
        Account acc1 = new Account(Name = 'Test Account', Email__c = 'test@gmail.com', type='Customer');
        insert acc1;

        Contact con = new Contact(Lastname = 'Test Contact', AccountId = acc.id, Phone = '1234567890');
        insert con;

        Asset asst = new Asset(Name = 'Test Asset', AccountId = acc.id, ContactId = con.id);
        insert asst;

        Id standardPricebookId = test.getStandardPricebookId();
        
        Product2 product = new Product2(Name = 'Test Product', Type__c = 'Parts', HSN_Code__c = 'TESTHSN', ProductCode= '767986uu', IsActive = true);
        insert product;
        
        PricebookEntry newPricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000000,
            IsActive = true // You can set other fields as needed
        );
        insert newPricebookEntry;
        
        Pricebook2 priceBook = new Pricebook2();
        priceBook.Id = standardPricebookId;
        priceBook.IsActive = true;
        update priceBook;

        VehicleDefinition vehiDefi = new VehicleDefinition(Name = 'Test Definition', ProductId = product.id);
        insert vehiDefi;

        Software_Version__c softwareVersion = new Software_Version__c(Name = 'Test Version 1');
        insert softwareVersion;

        Vehicle vac = new Vehicle(
            Name = 'Test Vehicle',
            assetId = asst.id,
            VehicleIdentificationNumber = 'VIN123456789',
            VehicleRegistrationNumber = 'VIN123456789',
            VehicleDefinitionId = vehiDefi.id,
            Software_Version__c = softwareVersion.id,
            CurrentOwnerId = acc.id,
            PDI_Status_Pass__c = true,
            Charger_PC_Number__c = 'ABC12'
        );
        insert vac;
        
        AssetMilestone milestone4 = new AssetMilestone();
        milestone4.Name = 'Test Milestone';
        milestone4.AssetId = asst.Id;
        milestone4.UsageType = 'Automotive';
        milestone4.MilestoneDate = System.today();
        milestone4.MilestoneType = 'PDI';
        milestone4.Stage = 'Active';
        milestone4.VehicleId = vac.Id;
        insert milestone4;
        
        Vehicle vac1 = new Vehicle(
            Id = vac.Id,
            PDI_Status_Pass__c = true
        );
        
        update vac1;
        
        PriceBookEntry entry = newPricebookEntry;
        Id PriceBookId = newPricebookEntry.PriceBook2Id;
        Product2 newProduct = product;
        
        // Create a Standard Order record
        Order standardOrder = new Order(
            AccountId = acc.Id,
            Website_Order_Id__c = 'RTYU456789',
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Description = 'Nothing',
            pricebook2Id = PriceBookId,
            Handling_Charges__c = 1000,
            Insurance_Amount__c = 1000,
            RTO_Charges__c = 1000,
            //Payment_Type__c = itemPaymentType,
            Notify_By_SMS__c = true,
            Notify_By_Email__c = true,
            BillingStreet = 'Bangalore',
            BillingCity = 'Bangalore',
            BillingState = 'Karnataka',
            BillingPostalCode = '574216',
            BillingCountry = 'india',
            Assigned_Vehicle__c = vac.Id
        );
        Insert standardOrder;
        
        OrderItem orderItem = new OrderItem(
            OrderId = standardOrder.Id,
            PricebookEntryId = entry.Id,
            Product2Id = newProduct.Id,
            Quantity = 1, 
            UnitPrice = 1056765,
            Type__c = 'Vehicle'
        );
        
        AssetMilestone milestone5 = new AssetMilestone();
        milestone5.Name = 'Test Milestone';
        milestone5.AssetId = asst.Id;
        milestone5.UsageType = 'Automotive';
        milestone5.MilestoneDate = System.today();
        milestone5.MilestoneType = 'Sold';
        milestone5.Stage = 'Active';
        milestone5.VehicleId = vac.Id;
        insert milestone5;
        
        

        // Create ContentDocumentLink
        ContentVersion cv = new ContentVersion(
            Title = 'Test Content',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;

        ContentDocument cd = [SELECT Id FROM ContentDocument LIMIT 1];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = acc.Id,
            ShareType = 'I'
        );
        insert cdl;

        // Test Case creation with valid data
        Test.startTest();
        Case newCase = new Case(
            AccountId = acc.Id,
            ContactId = con.Id,
            Subject__c = 'Parts concern',
            Status = 'New',
            Case_Type__c = 'Urgent Complaint',
            Vehicle_Registration_Number__c = 'VIN123456789',
            Category__c = 'Minor',
            case_category__c = 'Price',
            Description = 'Test '
        );
        insert newCase;
        
        Case newCase1 = new Case(
            AccountId = acc.Id,
            ContactId = con.Id,
            Subject__c = 'Parts concern',
            Status = 'New',
            Case_Type__c = 'Urgent Complaint',
            Vehicle_Registration_Number__c = 'VIN123456789',
            Category__c = 'Minor',
            case_category__c = 'Price',
            Description = 'Test '
        );
        insert newCase1;
        
        ContentDocumentLink cdl1 = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = newCase.Id,
            ShareType = 'I'
        );
        insert cdl1;
        
        Customer_feedBack__c cf= new Customer_feedBack__c(
            case__c = newCase.Id,
        	Issue_Type__c = 'Price'
        );
        insert cf;
        
        Customer_feedBack__c cf1 = new Customer_feedBack__c(
            case__c = newCase1.Id,
        	Issue_Type__c = 'Price'
        );
        insert cf1;
        
        newCase.Status='Closed';
        update newCase;
        
        try{
            newCase1.Status='Closed';
            update newCase1;
        }catch(DmlException ee){
            System.assertEquals('Please ensure that a Customer Feedback Form is attached before proceeding to close the urgent case.', ee.getDmlMessage(0));
        }
        
        
        Case newCase2 = new Case(
            AccountId = acc.Id,
            ContactId = con.Id,
            Subject__c = 'Parts concern',
            Status = 'New',
            Case_Type__c = 'Urgent Complaint',
            Vehicle_Registration_Number__c = 'VIN123456789',
            Category__c = 'Minor',
            Description = 'Test '
        );
        insert newCase2;
        
        ContentDocumentLink cdl2 = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = newCase2.Id,
            ShareType = 'I'
        );
        insert cdl2;
        
        try{
            newCase2.Status='Closed';
            update newCase2;
        }catch(DmlException ee){
            System.assertEquals('Related Customer Feedback is not Found!', ee.getDmlMessage(0));
        }
        
        
        Case newCaseWithVehicleError = new Case(
            AccountId = acc.Id,
            ContactId = con.Id,
            Subject__c = 'Price concern',
            Status = 'New',
            Case_Type__c = 'Urgent Complaint',
            Vehicle_Registration_Number__c = 'NonExistentVIN',
            Description = 'Test '
        );
        
        try {
            insert newCaseWithVehicleError;
        } catch(DmlException e) {
            System.assertEquals('Vehicle does not exists. Please check VRN Number.', e.getDmlMessage(0));
            try {
                newCase.AccountId = acc1.id;
                update newCase;
            } catch(DmlException ee) {
                System.assertEquals('This Vehicle is not related to Account.', ee.getDmlMessage(0));
            }
        }
        
        Test.stopTest();
    }
}