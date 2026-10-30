/**
 * Quote Line Item Trigger Handler
 *
 * Business Rule:
 * Every Infusion Pump sold requires a
 * 1-year Annual Maintenance Contract (AMC).
 *
 * When pump products are added to a quote,
 * automatically add one AMC line.
 *
 * AMC quantity = Total Pump Quantity
 *
 * Example:
 * Pump A Qty = 3
 * Pump B Qty = 2
 *
 * Total Pumps = 5
 * AMC Qty = 5
 * 
 * Flow:
 * Pump Quote Line Added
            │
            ▼
    After Insert Trigger
            │
            ▼
    Is Product Family =
    "Infusion Pumps"?
            │
            Yes
            │
            ▼
    AMC Already Exists?
            │
        Yes ───────► Stop
            │
            No
            │
            ▼
    Count Total Pumps
            │
            ▼
    Find AMC Product
    in Quote Pricebook
            │
            ▼
    Create AMC Line
    Qty = Total Pumps
            │
            ▼
    Insert AMC Line
 */
public with sharing class QuoteLineItemTriggerHandler extends TriggerHandler {

    // Product Family that represents pumps
    @TestVisible
    private static final String PUMP_FAMILY = 'Infusion Pumps';

    // AMC Product Code
    @TestVisible
    private static final String AMC_PRODUCT_CODE = 'CN-AMC-1Y';

    /**
     * Runs after Quote Line Items are inserted.
     */
    protected override void afterInsert() {
        addMaintenanceLines((List<QuoteLineItem>) Trigger.new);
    }

    /**
     * Adds AMC line automatically when pumps are added.
     */
    private void addMaintenanceLines(List<QuoteLineItem> newLines) {

        // Store IDs of newly inserted quote lines
        Set<Id> newLineIds =
            new Map<Id, QuoteLineItem>(newLines).keySet();

        // Collect Quote IDs
        Set<Id> quoteIds = new Set<Id>();

        for (QuoteLineItem line : newLines) {
            quoteIds.add(line.QuoteId);
        }

        //---------------------------------------------------
        // STEP 1:
        // Analyze all quote lines on affected quotes
        //---------------------------------------------------

        // Total pump quantity per quote
        Map<Id, Decimal> pumpsPerQuote =
            new Map<Id, Decimal>();

        // Quotes containing newly added pumps
        Set<Id> quotesWithNewPumps =
            new Set<Id>();

        // Quotes already having AMC line
        Set<Id> quotesWithAmc =
            new Set<Id>();

        for (QuoteLineItem line : [
            SELECT Id,
                   QuoteId,
                   Quantity,
                   Product2.Family,
                   Product2.ProductCode
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ]) {

            // Check if this is an AMC product
            if (line.Product2.ProductCode ==
                AMC_PRODUCT_CODE) {

                quotesWithAmc.add(line.QuoteId);
            }

            // Check if this is a Pump product
            else if (line.Product2.Family ==
                     PUMP_FAMILY) {

                Decimal currentTotal =
                    pumpsPerQuote.containsKey(line.QuoteId)
                    ? pumpsPerQuote.get(line.QuoteId)
                    : 0;

                pumpsPerQuote.put(
                    line.QuoteId,
                    currentTotal + line.Quantity
                );

                // Was this pump added in current transaction?
                if (newLineIds.contains(line.Id)) {
                    quotesWithNewPumps.add(line.QuoteId);
                }
            }
        }

        // Remove quotes that already have AMC
        quotesWithNewPumps.removeAll(quotesWithAmc);

        // Nothing to do
        if (quotesWithNewPumps.isEmpty()) {
            return;
        }

        //---------------------------------------------------
        // STEP 2:
        // Find AMC product price from quote pricebook
        //---------------------------------------------------

        Map<Id, Id> pricebookByQuote =
            new Map<Id, Id>();

        for (Quote q : [
            SELECT Id, Pricebook2Id
            FROM Quote
            WHERE Id IN :quotesWithNewPumps
        ]) {
            pricebookByQuote.put(
                q.Id,
                q.Pricebook2Id
            );
        }

        // AMC product entry by pricebook
        Map<Id, PricebookEntry> amcByPricebook =
            new Map<Id, PricebookEntry>();

        for (PricebookEntry entry : [

            SELECT Id,
                   Pricebook2Id,
                   UnitPrice

            FROM PricebookEntry

            WHERE Product2.ProductCode =
                :AMC_PRODUCT_CODE

            AND IsActive = true

            AND Pricebook2Id IN
                :pricebookByQuote.values()
        ]) {

            amcByPricebook.put(
                entry.Pricebook2Id,
                entry
            );
        }

        //---------------------------------------------------
        // STEP 3:
        // Create AMC quote line
        //---------------------------------------------------

        List<QuoteLineItem> amcLines =
            new List<QuoteLineItem>();

        for (Id quoteId : quotesWithNewPumps) {

            PricebookEntry amc =
                amcByPricebook.get(
                    pricebookByQuote.get(quoteId)
                );

            // If AMC product doesn't exist
            // in this Price Book, skip
            if (amc == null) {
                continue;
            }

            amcLines.add(
                new QuoteLineItem(

                    QuoteId = quoteId,

                    PricebookEntryId = amc.Id,

                    // AMC quantity equals
                    // total number of pumps
                    Quantity =
                        pumpsPerQuote.get(quoteId),

                    UnitPrice =
                        amc.UnitPrice,

                    Description =
                        '1-year maintenance, 1 per pump (added automatically)'
                )
            );
        }

        // Insert all AMC lines at once
        if (!amcLines.isEmpty()) {
            insert amcLines;
        }
    }
}