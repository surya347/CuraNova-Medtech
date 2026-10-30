@IsTest
private class QuoteLineItemTriggerHandlerTest {

    @TestSetup
    static void createCatalogAndQuote() {
        Id standardBook = Test.getStandardPricebookId();
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Test Pump', ProductCode = 'TEST-PUMP', Family = 'Infusion Pumps', IsActive = true),
            new Product2(Name = 'Test AMC', ProductCode = 'CN-AMC-1Y', Family = 'Services', IsActive = true),
            new Product2(Name = 'Test Sensor', ProductCode = 'TEST-SENSOR', Family = 'Consumables', IsActive = true)
        };
        insert products;
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = standardBook, Product2Id = products[0].Id, UnitPrice = 100000, IsActive = true),
            new PricebookEntry(Pricebook2Id = standardBook, Product2Id = products[1].Id, UnitPrice = 10000, IsActive = true),
            new PricebookEntry(Pricebook2Id = standardBook, Product2Id = products[2].Id, UnitPrice = 4000, IsActive = true)
        };

        Account hospital = new Account(Name = 'Test Quote Hospital', Hospital_Type__c = 'Private');
        insert hospital;
        Opportunity deal = new Opportunity(Name = 'Test quote deal', AccountId = hospital.Id, StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), Pricebook2Id = standardBook);
        insert deal;
        insert new Quote(Name = 'Test Quote', OpportunityId = deal.Id, Pricebook2Id = standardBook);
    }

    private static Id quoteId() {
        return [SELECT Id FROM Quote LIMIT 1].Id;
    }

    private static PricebookEntry entry(String productCode) {
        return [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2.ProductCode = :productCode LIMIT 1];
    }

    private static QuoteLineItem line(String productCode, Integer quantity) {
        PricebookEntry e = entry(productCode);
        return new QuoteLineItem(QuoteId = quoteId(), PricebookEntryId = e.Id, Quantity = quantity, UnitPrice = e.UnitPrice);
    }

    private static List<QuoteLineItem> amcLines() {
        return [SELECT Quantity, UnitPrice FROM QuoteLineItem
                WHERE QuoteId = :quoteId() AND Product2.ProductCode = 'CN-AMC-1Y'];
    }

    @IsTest
    static void addsOneAmcPerPump() {
        Test.startTest();
        insert line('TEST-PUMP', 5);
        Test.stopTest();

        List<QuoteLineItem> amc = amcLines();
        Assert.areEqual(1, amc.size(), 'Expected one AMC line');
        Assert.areEqual(5, amc[0].Quantity.intValue(), 'One AMC per pump');
        Assert.areEqual(10000, amc[0].UnitPrice.intValue(), 'Priced from the quote price book');
    }

    @IsTest
    static void ignoresNonPumpProducts() {
        insert line('TEST-SENSOR', 10);
        Assert.areEqual(0, amcLines().size(), 'Sensors do not need an AMC');
    }

    @IsTest
    static void neverAddsASecondAmcLine() {
        insert line('TEST-PUMP', 2);
        insert line('TEST-PUMP', 3);
        Assert.areEqual(1, amcLines().size(), 'Only one AMC line per quote');
    }

    @IsTest
    static void skipsWhenPriceBookHasNoAmc() {
        PricebookEntry amc = entry('CN-AMC-1Y');
        amc.IsActive = false;
        update amc;

        insert line('TEST-PUMP', 4);
        Assert.areEqual(0, amcLines().size(), 'No active AMC price, so no AMC line and no error');
    }
}
