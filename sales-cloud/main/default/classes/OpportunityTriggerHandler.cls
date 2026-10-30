/**
 * Opportunity Trigger Handler
 *
 * Business Rule:
 * Government and Trust hospitals purchase through tenders.
 * Therefore, when an Opportunity reaches certain stages,
 * Tender Reference is mandatory.
 *
 * Applies only to:
 *   - Government hospitals
 *   - Trust hospitals
 *
 * Does NOT apply to:
 *   - Private hospitals
 *   - Clinics
 * 
 * Flow:
 * User Saves Opportunity
            |
            v
    beforeInsert / beforeUpdate
            |
            v
    Stage in restricted stages?
            |
        Yes
            |
            v
    Tender Reference blank?
            |
        Yes
            |
            v
    Get Account's Hospital Type
            |
            +--> Private/Clinic ---> Allow Save
            |
            +--> Government/Trust ---> Show Error
                                        |
                                        v
                                    Block Save
 */
public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    // Hospital types that require Tender Reference
    private static final Set<String> TENDER_HOSPITAL_TYPES =
        new Set<String>{ 'Government', 'Trust' };

    // Stages where Tender Reference becomes mandatory
    private static final Set<String> TENDER_STAGES =
        new Set<String>{
            'Proposal/Price Quote',
            'Negotiation/Review',
            'Closed Won'
        };

    /**
     * Runs before a new Opportunity is inserted.
     */
    protected override void beforeInsert() {
        requireTenderReference((List<Opportunity>) Trigger.new);
    }

    /**
     * Runs before an existing Opportunity is updated.
     */
    protected override void beforeUpdate() {
        requireTenderReference((List<Opportunity>) Trigger.new);
    }

    /**
     * Validates that Government/Trust hospital opportunities
     * have a Tender Reference before reaching key sales stages.
     */
    private void requireTenderReference(List<Opportunity> opportunities) {

        // Opportunities that need validation
        List<Opportunity> toCheck = new List<Opportunity>();

        // Store Account IDs for a single SOQL query
        Set<Id> accountIds = new Set<Id>();

        // Find Opportunities that might violate the rule
        for (Opportunity opp : opportunities) {

            // Check:
            // 1. Opportunity has an Account
            // 2. Stage is one of the restricted stages
            // 3. Tender Reference is blank
            if (opp.AccountId != null
                && TENDER_STAGES.contains(opp.StageName)
                && String.isBlank(opp.Tender_Reference__c)) {

                toCheck.add(opp);
                accountIds.add(opp.AccountId);
            }
        }

        // Nothing to validate
        if (toCheck.isEmpty()) {
            return;
        }

        // Query all related Accounts in one SOQL
        // (Bulk-safe: no query inside loops)
        Map<Id, Account> hospitals =
            new Map<Id, Account>(
                [SELECT Id, Hospital_Type__c
                 FROM Account
                 WHERE Id IN :accountIds]
            );

        // Validate each Opportunity
        for (Opportunity opp : toCheck) {

            Account hospital = hospitals.get(opp.AccountId);

            // If Account is Government or Trust hospital
            if (hospital != null
                && TENDER_HOSPITAL_TYPES.contains(
                    hospital.Hospital_Type__c)) {

                // Prevent save and show error message
                opp.addError(
                    Opportunity.Tender_Reference__c,
                    hospital.Hospital_Type__c +
                    ' hospitals buy through tenders. ' +
                    'Enter the Tender Reference before moving to ' +
                    opp.StageName + '.'
                );
            }
        }
    }
}