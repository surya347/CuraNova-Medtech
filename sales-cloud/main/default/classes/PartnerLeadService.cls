/**
 * S3: Partner Leads API
 *
 * Purpose:
 * External distributors can send new hospital leads to Salesforce.
 *
 * Endpoint:
 * POST /services/apexrest/partner-leads/v1
 *
 * Example Request:
 * {
 *   "firstName":"Rahul",
 *   "lastName":"Sharma",
 *   "company":"City Hospital",
 *   "hospitalType":"Private",
 *   "bedCount":150,
 *   "partnerName":"ABC Distributor"
 * }
 *
 * Salesforce will:
 * 1. Validate the request
 * 2. Create a Lead
 * 3. Run active Lead Assignment Rules
 * 4. Check duplicate rules
 * 5. Return a success/failure response
 * 
 * FLOW : 
 * Partner System
      |
      | POST Request (JSON)
      v
    PartnerLeadService.createLead()
      |
      +--> Parse JSON
      |
      +--> Validate required fields
      |
      +--> Create Lead object
      |
      +--> Run Lead Assignment Rule
      |
      +--> Check Duplicate Rules
      |
      +--> Insert Lead
      |
      v
JSON Response Returned

Success:
{
  "success": true,
  "leadId": "00Qxx000000123A",
  "message": "Lead created."
}

Failure:
{
  "success": false,
  "leadId": null,
  "message": "lastName and company are required."
}
 */
@RestResource(urlMapping='/partner-leads/v1/*')
global with sharing class PartnerLeadService {

    /*
     * Represents the JSON payload received from a partner.
     *
     * Example incoming JSON:
     * {
     *   "firstName":"Rahul",
     *   "lastName":"Sharma",
     *   "company":"City Hospital"
     * }
     *
     * Salesforce automatically maps JSON fields
     * into these Apex variables during deserialization.
     */
    public class PartnerLead {
        public String firstName;
        public String lastName;
        public String company;
        public String title;
        public String email;
        public String phone;
        public String city;
        public String hospitalType;
        public Integer bedCount;
        public String partnerName;
    }

    /**
     * Handles HTTP POST requests.
     *
     * Called when someone sends:
     * POST /services/apexrest/partner-leads/v1
     */
    @HttpPost
    global static void createLead() {

        // Get the incoming REST request.
        RestRequest req = RestContext.request;

        /*
         * STEP 1: Read and parse the JSON request body.
         *
         * Example:
         * {
         *   "firstName":"Rahul",
         *   "lastName":"Sharma"
         * }
         */
        PartnerLead input;

        try {
            // Convert JSON into PartnerLead Apex object.
            input = (PartnerLead)
                JSON.deserialize(
                    req.requestBody.toString(),
                    PartnerLead.class
                );
        } catch (Exception e) {

            // Invalid JSON format.
            // Example:
            // this is not json
            respond(
                400,
                false,
                null,
                'The request body must be valid JSON.'
            );
            return;
        }

        /*
         * STEP 2: Validate required fields.
         *
         * Required:
         * - lastName
         * - company
         *
         * Example invalid request:
         * {
         *   "company":""
         * }
         */
        if (
            input == null ||
            String.isBlank(input.lastName) ||
            String.isBlank(input.company)
        ) {
            respond(
                400,
                false,
                null,
                'lastName and company are required.'
            );
            return;
        }

        /*
         * STEP 3: Create the Lead record.
         *
         * Maps incoming JSON fields
         * to Salesforce Lead fields.
         */
        Lead newLead = new Lead(

            // Standard Lead fields
            FirstName = input.firstName,
            LastName = input.lastName,
            Company = input.company,
            Title = input.title,
            Email = input.email,
            Phone = input.phone,
            City = input.city,

            // Default values set by business rules
            Country = 'India',
            Industry = 'Healthcare',
            LeadSource = 'Partner Referral',

            // Custom fields
            Hospital_Type__c = input.hospitalType,
            Bed_Count__c = input.bedCount,

            /*
             * If partnerName exists, save it
             * in Description.
             *
             * Example:
             * "Sent by partner: ABC Distributor"
             */
            Description =
                String.isBlank(input.partnerName)
                ? null
                : 'Sent by partner: ' + input.partnerName
        );

        /*
         * STEP 4: Insert the Lead.
         *
         * Normally Apex-created Leads do NOT run
         * Lead Assignment Rules.
         *
         * By setting useDefaultRule = true,
         * Salesforce executes the active Lead
         * Assignment Rule after insert.
         */
        Database.DMLOptions options =
            new Database.DMLOptions();

        // Run active Lead Assignment Rule.
        options.assignmentRuleHeader.useDefaultRule = true;

        // Allow partial processing instead of throwing exception.
        options.optAllOrNone = false;

        // Insert the Lead using custom DML options.
        Database.SaveResult result =
            Database.insert(newLead, options);

        /*
         * STEP 5: Return result back to partner.
         */

        // Lead created successfully.
        if (result.isSuccess()) {

            respond(
                201,                 // HTTP Created
                true,
                result.getId(),
                'Lead created.'
            );
            return;
        }

        /*
         * Check whether Salesforce duplicate rules
         * blocked the record.
         *
         * Example:
         * Same hospital already exists.
         */
        for (Database.Error err : result.getErrors()) {

            if (err instanceof Database.DuplicateError) {

                respond(
                    409, // HTTP Conflict
                    false,
                    null,
                    'This lead already exists in CuraNova.'
                );
                return;
            }
        }

        /*
         * Any other validation error.
         *
         * Example:
         * Invalid picklist value
         * Validation rule failure
         * Required field missing
         */
        respond(
            400,
            false,
            null,
            result.getErrors()[0].getMessage()
        );
    }

    /**
     * Helper method used to build
     * consistent JSON responses.
     *
     * Example Success Response:
     * {
     *   "success": true,
     *   "leadId": "00QXXXXXXXXXXXX",
     *   "message": "Lead created."
     * }
     *
     * Example Error Response:
     * {
     *   "success": false,
     *   "leadId": null,
     *   "message": "lastName and company are required."
     * }
     */
    private static void respond(
        Integer status,
        Boolean success,
        Id leadId,
        String message
    ) {

        // Get response object.
        RestResponse res = RestContext.response;

        // Set HTTP status code.
        res.statusCode = status;

        // Tell client we're returning JSON.
        res.addHeader('Content-Type', 'application/json');

        // Build JSON response body.
        res.responseBody =
            Blob.valueOf(
                JSON.serialize(
                    new Map<String, Object>{
                        'success' => success,
                        'leadId' => leadId,
                        'message' => message
                    }
                )
            );
    }
}