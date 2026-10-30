// One trigger per object. All logic lives in OpportunityTriggerHandler.
trigger OpportunityTrigger on Opportunity (before insert, before update) {
    new OpportunityTriggerHandler().run();
}
