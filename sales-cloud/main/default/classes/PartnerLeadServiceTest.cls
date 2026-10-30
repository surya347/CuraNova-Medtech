@IsTest
private class PartnerLeadServiceTest {

    // Calls the endpoint the same way Salesforce does for a real HTTP request.
    private static RestResponse callApi(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/partner-leads/v1';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        PartnerLeadService.createLead();
        return RestContext.response;
    }

    @IsTest
    static void createLeadUsingRealSampleData() {

        String body =
        '{"firstName":"Sameer",' +
        '"lastName":"Kale",' +
        '"company":"Viman Nagar Lifeline Hospital",' +
        '"title":"Purchase Manager",' +
        '"email":"sameer.kale.demo@example.com",' +
        '"city":"Pune",' +
        '"hospitalType":"Private",' +
        '"bedCount":140,' +
        '"partnerName":"Sahyadri Medical Distributors"}';

        Test.startTest();
        RestResponse res = callApi(body);
        Test.stopTest();

        System.assertEquals(201, res.statusCode);

        Map<String,Object> responseMap =
            (Map<String,Object>) JSON.deserializeUntyped(
                res.responseBody.toString()
            );

        System.assertEquals(true, responseMap.get('success'));
        System.assertNotEquals(null, responseMap.get('leadId'));
    }

    private static Map<String, Object> bodyOf(RestResponse res) {
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @IsTest
    static void createsLeadFromPartner() {
        String body = '{"firstName":"Test","lastName":"Partner Lead","company":"Viman Nagar Test Hospital",'
            + '"city":"Pune","hospitalType":"Private","bedCount":90,"partnerName":"Sahyadri Medical Distributors"}';

        Test.startTest();
        RestResponse res = callApi(body);
        Test.stopTest();

        Assert.areEqual(201, res.statusCode, 'Expected 201 Created: ' + res.responseBody.toString());
        Id leadId = (Id) bodyOf(res).get('leadId');
        Lead created = [SELECT Company, LeadSource, Hospital_Type__c, Bed_Count__c, Description
                        FROM Lead WHERE Id = :leadId];
        Assert.areEqual('Viman Nagar Test Hospital', created.Company);
        Assert.areEqual('Partner Referral', created.LeadSource);
        Assert.areEqual('Private', created.Hospital_Type__c);
        Assert.areEqual(90, created.Bed_Count__c.intValue());
        Assert.isTrue(created.Description.contains('Sahyadri Medical Distributors'));
    }

    @IsTest
    static void rejectsMissingRequiredFields() {
        RestResponse res = callApi('{"firstName":"No","company":""}');
        Assert.areEqual(400, res.statusCode);
        Assert.areEqual(false, bodyOf(res).get('success'));
    }

    @IsTest
    static void rejectsInvalidJson() {
        RestResponse res = callApi('this is not json');
        Assert.areEqual(400, res.statusCode);
    }

    @IsTest
    static void rejectsUnknownHospitalType() {
        RestResponse res = callApi('{"lastName":"Test","company":"Bad Type Hospital","hospitalType":"Military"}');
        Assert.areEqual(400, res.statusCode, 'A value outside the restricted picklist should be rejected');
    }
}
