@IsTest
private class DealHealthControllerTest {
  private static Opportunity newDeal(
    String hospitalType,
    String nextStep,
    Date closeDate,
    String tender
  ) {
    Account hospital = new Account(
      Name = 'Health Test ' + hospitalType,
      Hospital_Type__c = hospitalType
    );
    insert hospital;
    Opportunity opp = new Opportunity(
      Name = 'Health test deal',
      AccountId = hospital.Id,
      StageName = 'Qualification',
      CloseDate = closeDate,
      NextStep = nextStep,
      Tender_Reference__c = tender
    );
    insert opp;
    return opp;
  }

  @IsTest
  static void privateDealMissingEverythingIsAtRisk() {
    Opportunity opp = newDeal('Private', null, Date.today().addDays(-5), null);

    DealHealthController.Health health = DealHealthController.getHealth(opp.Id);

    Assert.areEqual(
      4,
      health.checks.size(),
      'No tender check for Private hospitals'
    );
    Assert.areEqual(0, health.score);
    Assert.areEqual('At risk', health.status);
  }

  @IsTest
  static void governmentDealGetsTenderCheck() {
    Opportunity opp = newDeal(
      'Government',
      'Demo at ICU',
      Date.today().addDays(30),
      'GEM/TEST/1'
    );

    DealHealthController.Health health = DealHealthController.getHealth(opp.Id);

    Assert.areEqual(
      5,
      health.checks.size(),
      'Government hospitals get the tender check'
    );
    // Passed: close date, next step, tender. Missing: products, primary contact. 3 of 5 = 60%
    Assert.areEqual(60, health.score);
    Assert.areEqual('Needs attention', health.status);
  }

  @IsTest
  static void completeDealIsHealthy() {
    Opportunity opp = newDeal(
      'Private',
      'Send quote',
      Date.today().addDays(30),
      null
    );
    Contact buyer = new Contact(LastName = 'Buyer', AccountId = opp.AccountId);
    insert buyer;
    insert new OpportunityContactRole(
      OpportunityId = opp.Id,
      ContactId = buyer.Id,
      Role = 'Decision Maker',
      IsPrimary = true
    );

    Id standardBook = Test.getStandardPricebookId();
    Product2 pump = new Product2(
      Name = 'Health Test Pump',
      Family = 'Infusion Pumps',
      IsActive = true
    );
    insert pump;
    PricebookEntry entry = new PricebookEntry(
      Pricebook2Id = standardBook,
      Product2Id = pump.Id,
      UnitPrice = 1000,
      IsActive = true
    );
    insert entry;
    opp.Pricebook2Id = standardBook;
    update opp;
    insert new OpportunityLineItem(
      OpportunityId = opp.Id,
      PricebookEntryId = entry.Id,
      Quantity = 1,
      UnitPrice = 1000
    );

    DealHealthController.Health health = DealHealthController.getHealth(opp.Id);

    Assert.areEqual(100, health.score);
    Assert.areEqual('Healthy', health.status);
  }
}
