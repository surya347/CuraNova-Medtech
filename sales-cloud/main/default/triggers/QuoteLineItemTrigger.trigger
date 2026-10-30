// One trigger per object. All logic lives in QuoteLineItemTriggerHandler.
trigger QuoteLineItemTrigger on QuoteLineItem (after insert) {
    new QuoteLineItemTriggerHandler().run();
}
