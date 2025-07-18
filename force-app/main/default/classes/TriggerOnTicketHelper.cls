public class TriggerOnTicketHelper {
    public static void afterTicketUpdate(List<Ticket__c> newTickets) {
        List<Ticket__c> ticketsToUpdate = new List<Ticket__c>();

        for (Ticket__c tikt : newTickets) {
            if (tikt.Resolution__c != null && tikt.Resolution__c != tikt.Resolution_History__c) {
                Ticket__c t = new Ticket__c(
                    Id = tikt.Id,
                    Resolution_History__c = tikt.Resolution__c
                );
                ticketsToUpdate.add(t);
            }
        }

        if (!ticketsToUpdate.isEmpty()) {
            update ticketsToUpdate;
        }
    }
}