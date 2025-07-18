/**
* @File Name : UserTrackingcontroller.cls
* @Description :
* @Author : Anwar Chikle
* @Last Modified By :
* @Last Modified On : March 12, 2025
* @Modification Log : 
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | March 12, 2025 |   | Initial Version
**/

public class UserTrackingcontroller {
    
    @AuraEnabled
    public static UserTrack OnpageLoad(string userId){
        UserTrack usr = new UserTrack();
        try{
            String LoggedInUser = UserInfo.getUserId();
            
            
            System.debug('LoggedInUser =====> ' + LoggedInUser);
            list<User_Tracking__c> userTracking = [select id, Checkin_Datetime__c, Checkout_Datetime__c, Member__c
                                                   from User_Tracking__c
                                                   where Member__c = :userId and CreatedDate = TODAY
                                                   limit 1];
            
            
            if (!userTracking.isEmpty()){
                usr.checkin = true;
                if (userTracking[0].Checkout_Datetime__c != null){
                    System.debug('checkout ===> ');
                    usr.checkout = true;
                } else{
                    System.debug('checkout in this ===> ');
                    usr.checkout = false;
                }
            } else{
                usr.checkin = false;
                usr.checkout = true;
            }
        } catch (Exception e){
            System.debug('stack trace ======> ' + e.getStackTraceString());
        }
        return usr;
    }
    
    @AuraEnabled
    public static UserTrackWrapperAfterCheckin UserCheckin(string userId){
        /*if(System.now().time() < Time.newInstance(08, 59, 00, 00)){

}else{}*/
        
        UserTrackWrapperAfterCheckin UserTrackWrap = new UserTrackWrapperAfterCheckin();
        String eventStatus = 'Something went wrong';
        string groupName = '';
        DateTime dt = DateTime.now();
        String dayOfWeek = dt.format('EEEE');
        // if (boolean.valueOf(system.label.Enable_Sunday_Checkin)){
        //     if (dayOfWeek == 'Sunday'){
        //         eventStatus = 'You can not checkin on Sundayr.';
        //         //return eventStatus;
        //     }
        // }
        
        
        if (System.now().time() < Time.newInstance(08, 59, 00, 00)){
            eventStatus = 'You can not checkin before 9:00 AM.';
            //return eventStatus;
        }
        
        map<string, string> mapofGroupNameBySourceIntent = new map<string, string>();
        if (userId != null){
            list<User_Tracking__c> userTracking = new list<User_Tracking__c>();
            list<Assignment_Group_Member__c> agmList = new list<Assignment_Group_Member__c>();
            userTracking = [select id, Checkin_Datetime__c, Checkout_Datetime__c, Member__c
                            from User_Tracking__c
                            where Member__c = :userId and CreatedDate = TODAY
                            limit 1];
            system.debug('userTracking::'+userTracking);
            agmList = [select id, Group_Member__c, Assignment_Group__r.name,Out_Of_Office__c
                       from Assignment_Group_Member__c
                       where Group_Member__c = :userId];
            system.debug('agmList::'+agmList);
            
            
            if (userTracking.isEmpty()){
                User_Tracking__c userTrackRec = new User_Tracking__c();
                userTrackRec.Member__c = userId;
                userTrackRec.Checkin_Datetime__c = DateTime.now();
                insert userTrackRec;
                if (!agmList.isEmpty()){
                    for (Assignment_Group_Member__c agm : agmList){
                        agm.Out_Of_Office__c = false;
                        
                    }
                    update agmList;
                    if(userTrackRec.Checkin_Datetime__c != null){
                        SobjectLoadAssignment.ExecuteLoadAssignment(5);
                    }
                }
                eventStatus = 'Checkin successful';
            } else{
                eventStatus = 'Your checkin was already created.';
            }
            
        } else{
            eventStatus = 'User is not registered in system.Please contact to your admin.';
        }
        UserTrackWrap.eventStatus = eventStatus;
        return UserTrackWrap;
    }
    
    @AuraEnabled
    public static String UserCheckout(string userId){
        String eventStatus = 'Something went wrong';
        
        
        if (userId != null){
            list<User_Tracking__c> userTracking = new list<User_Tracking__c>();
            list<Assignment_Group_Member__c> agmList = new list<Assignment_Group_Member__c>();
            
            
            userTracking = [select id, Checkin_Datetime__c, Checkout_Datetime__c, Member__c
                            from User_Tracking__c
                            where Member__c = :userId and createddate = TODAY
                            limit 1];
            agmList = [select id, Group_Member__c
                       from Assignment_Group_Member__c
                       where Group_Member__c = :userId];
            if (!userTracking.isEmpty()){
                for (User_Tracking__c ut : userTracking){
                    ut.Checkout_Datetime__c = DateTime.now();
                }
                update userTracking;
               
                if (!agmList.isEmpty()){
                    for (Assignment_Group_Member__c agm : agmList){
                        agm.Out_Of_Office__c = true;
                    }
                    
                    update agmList;
                }
                
                eventStatus = 'Checkout datetime has been updated.';
            } else{
                eventStatus = 'You can not checkout without checkin.';
            }
            
        } else{
            eventStatus = 'User is not registered in system.Please contact to your admin.';
        }
        
        
        return eventStatus;
    }
      
    public class UserTrack{
        @AuraEnabled
        public boolean checkin;
        @AuraEnabled
        public boolean checkout;
        @AuraEnabled
        public String AOAvailableStatus;
    }
    
    public class UserTrackWrapperAfterCheckin{
        @AuraEnabled
        public String eventStatus; 
    }
}