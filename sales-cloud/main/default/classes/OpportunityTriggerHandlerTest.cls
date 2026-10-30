@IsTest
private class OpportunityTriggerHandlerTest {

    @TestSetup
    static void createHospitals() {
        insert new List<Account>{
            new Account(Name = 'Test Government Hospital', Hospital_Type__c = 'Government'),
            new Account(Name = 'Test Private Hospital', Hospital_Type__c = 'Private')
        };
    }

    private static Id hospitalId(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1].Id;
    }

    private static Opportunity deal(Id accountId, String stage, String tenderReference) {
        return new Opportunity(
            Name = 'Test pump deal',
            AccountId = accountId,
            StageName = stage,
            CloseDate = Date.today().addDays(30),
            Tender_Reference__c = tenderReference
        );
    }

    @IsTest
    static void blocksGovernmentProposalWithoutTender() {
        Database.SaveResult result = Database.insert(
            deal(hospitalId('Test Government Hospital'), 'Proposal/Price Quote', null), false);

        Assert.isFalse(result.isSuccess(), 'The deal should be blocked');
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Tender Reference'));
    }

    @IsTest
    static void allowsGovernmentProposalWithTender() {
        Database.SaveResult result = Database.insert(
            deal(hospitalId('Test Government Hospital'), 'Proposal/Price Quote', 'GEM/TEST/0001'), false);

        Assert.isTrue(result.isSuccess());
    }

    @IsTest
    static void allowsEarlyStageWithoutTender() {
        Database.SaveResult result = Database.insert(
            deal(hospitalId('Test Government Hospital'), 'Qualification', null), false);

        Assert.isTrue(result.isSuccess(), 'Early stages do not need a tender yet');
    }

    @IsTest
    static void allowsPrivateHospitalWithoutTender() {
        Database.SaveResult result = Database.insert(
            deal(hospitalId('Test Private Hospital'), 'Negotiation/Review', null), false);

        Assert.isTrue(result.isSuccess(), 'Private hospitals are not affected');
    }

    @IsTest
    static void blocksMovingStageForwardWithoutTender() {
        Opportunity opp = deal(hospitalId('Test Government Hospital'), 'Needs Analysis', null);
        insert opp;

        opp.StageName = 'Negotiation/Review';
        Database.SaveResult result = Database.update(opp, false);

        Assert.isFalse(result.isSuccess());
    }

    @IsTest
    static void handles200DealsAtOnce() {
        Id government = hospitalId('Test Government Hospital');
        List<Opportunity> deals = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            // Half have a tender reference, half don't
            deals.add(deal(government, 'Proposal/Price Quote', Math.mod(i, 2) == 0 ? 'GEM/BULK/' + i : null));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(deals, false);
        Test.stopTest();

        Integer saved = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                saved++;
            }
        }
        Assert.areEqual(100, saved, 'Only the deals with a tender reference should save');
    }

    @IsTest
    static void bypassSkipsTheRule() {
        TriggerHandler.bypass('OpportunityTriggerHandler');
        Database.SaveResult result = Database.insert(
            deal(hospitalId('Test Government Hospital'), 'Proposal/Price Quote', null), false);
        TriggerHandler.clearBypass('OpportunityTriggerHandler');

        Assert.isTrue(result.isSuccess(), 'A bypassed handler should not run');
    }
}
