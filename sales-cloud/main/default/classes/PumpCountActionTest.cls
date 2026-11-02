@IsTest
private class PumpCountActionTest {

    @TestSetup
    static void createDealWithProducts() {
        Id standardBook = Test.getStandardPricebookId();
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Test Volumetric Pump', Family = 'Infusion Pumps', IsActive = true),
            new Product2(Name = 'Test Syringe Pump', Family = 'Infusion Pumps', IsActive = true),
            new Product2(Name = 'Test Sensor', Family = 'Consumables', IsActive = true)
        };
        insert products;
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Product2 p : products) {
            entries.add(new PricebookEntry(Pricebook2Id = standardBook, Product2Id = p.Id, UnitPrice = 1000, IsActive = true));
        }
        insert entries;

        Account hospital = new Account(Name = 'Test Flow Hospital', Hospital_Type__c = 'Private');
        insert hospital;
        List<Opportunity> deals = new List<Opportunity>{
            new Opportunity(Name = 'Deal with pumps', AccountId = hospital.Id, StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30), Pricebook2Id = standardBook),
            new Opportunity(Name = 'Deal without pumps', AccountId = hospital.Id, StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30), Pricebook2Id = standardBook)
        };
        insert deals;
        insert new List<OpportunityLineItem>{
            new OpportunityLineItem(OpportunityId = deals[0].Id, PricebookEntryId = entries[0].Id, Quantity = 5, UnitPrice = 1000),
            new OpportunityLineItem(OpportunityId = deals[0].Id, PricebookEntryId = entries[1].Id, Quantity = 3, UnitPrice = 1000),
            new OpportunityLineItem(OpportunityId = deals[0].Id, PricebookEntryId = entries[2].Id, Quantity = 10, UnitPrice = 1000),
            new OpportunityLineItem(OpportunityId = deals[1].Id, PricebookEntryId = entries[2].Id, Quantity = 10, UnitPrice = 1000)
        };
    }

    private static PumpCountAction.Request requestFor(String dealName) {
        PumpCountAction.Request req = new PumpCountAction.Request();
        req.opportunityId = [SELECT Id FROM Opportunity WHERE Name = :dealName LIMIT 1].Id;
        return req;
    }

    @IsTest
    static void countsOnlyPumps() {
        List<PumpCountAction.Result> results = PumpCountAction.countPumps(
            new List<PumpCountAction.Request>{ requestFor('Deal with pumps') });

        Assert.areEqual(8, results[0].pumpCount, '5 + 3 pumps; sensors are not counted');
        Assert.areEqual('3 × Test Syringe Pump, 5 × Test Volumetric Pump', results[0].summary);
    }

    @IsTest
    static void returnsZeroWhenNoPumps() {
        List<PumpCountAction.Result> results = PumpCountAction.countPumps(
            new List<PumpCountAction.Request>{ requestFor('Deal without pumps') });

        Assert.areEqual(0, results[0].pumpCount);
        Assert.areEqual('No pumps on this deal', results[0].summary);
    }

    @IsTest
    static void keepsTheOrderOfManyRequests() {
        List<PumpCountAction.Result> results = PumpCountAction.countPumps(new List<PumpCountAction.Request>{
            requestFor('Deal without pumps'), requestFor('Deal with pumps')
        });

        Assert.areEqual(0, results[0].pumpCount);
        Assert.areEqual(8, results[1].pumpCount);
    }
}
