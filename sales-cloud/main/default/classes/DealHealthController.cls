/**
 * Deal Health Calculator
 *
 * Purpose:
 * Evaluate whether an Opportunity is in good shape.
 *
 * It checks things sales managers expect to see on every deal:
 * - Products added
 * - Primary contact assigned
 * - Close date not overdue
 * - Next step completed
 * - Tender reference (for Government/Trust hospitals)
 *
 * Final Result:
 * Score = Passed checks / Total checks * 100
 * 
 * 
 * This class is used by an LWC called dealHealthCard to calculate how healthy an Opportunity (Deal) is.

Think of it like a deal quality checklist.

Sales managers want to know:

 1 Products added?
 2 Primary contact set?
 3 Close date valid?
 4 Next step defined?
 5 Tender reference entered (if required)?

 *The class checks these items, calculates a score, and returns a status like:
  100% = Healthy
  60% = Needs attention
  20% = At risk
*
 */
public with sharing class DealHealthController {

    // Hospital types that require a Tender Reference
    private static final Set<String> TENDER_HOSPITAL_TYPES =
        new Set<String>{
            'Government',
            'Trust'
        };

    /**
     * Represents one individual health check
     * Example:
     * Label: Products added
     * Passed: true
     * Tip: Add products to the opportunity
     */
    public class Check {

        @AuraEnabled
        public String label;

        @AuraEnabled
        public Boolean passed;

        @AuraEnabled
        public String tip;

        Check(String label, Boolean passed, String tip) {
            this.label = label;
            this.passed = passed;
            this.tip = tip;
        }
    }

    /**
     * Complete health report sent back to the LWC
     */
    public class Health {

        // Overall score percentage
        @AuraEnabled
        public Integer score;

        // Healthy / Needs attention / At risk
        @AuraEnabled
        public String status;

        // Detailed checklist results
        @AuraEnabled
        public List<Check> checks = new List<Check>();
    }

    /**
     * Main method called by the LWC
     */
    @AuraEnabled(cacheable=true)
    public static Health getHealth(Id opportunityId) {

        // Fetch opportunity information needed for the checks
        Opportunity opp = [

            SELECT
                Id,
                CloseDate,
                IsClosed,
                NextStep,
                HasOpportunityLineItem,
                Tender_Reference__c,

                Account.Hospital_Type__c,

                (
                    SELECT Id
                    FROM OpportunityContactRoles
                    WHERE IsPrimary = TRUE
                    LIMIT 1
                )

            FROM Opportunity
            WHERE Id = :opportunityId

            WITH USER_MODE
        ];

        Health health = new Health();

        /*
         * Check #1
         * Does this opportunity have products?
         */
        health.checks.add(
            new Check(
                'Products added',
                opp.HasOpportunityLineItem,
                'Add the pumps or consumables from the Products related list.'
            )
        );

        /*
         * Check #2
         * Is a Primary Contact assigned?
         */
        health.checks.add(
            new Check(
                'Primary contact set',
                !opp.OpportunityContactRoles.isEmpty(),
                'Add a contact role and tick Primary.'
            )
        );

        /*
         * Check #3
         * Is the close date still valid?
         * Passed if:
         * - Opportunity already closed OR
         * - Close Date is today/future
         */
        health.checks.add(
            new Check(
                'Close date not overdue',
                opp.IsClosed ||
                opp.CloseDate >= Date.today(),
                'The close date has passed. Update it or close the deal.'
            )
        );

        /*
         * Check #4
         * Has the salesperson entered a Next Step?
         */
        health.checks.add(
            new Check(
                'Next step written',
                String.isNotBlank(opp.NextStep),
                'Write the next action in the Next Step field.'
            )
        );

        /*
         * Check #5
         * Required only for Government and Trust hospitals.
         */
        if (
            TENDER_HOSPITAL_TYPES.contains(
                opp.Account?.Hospital_Type__c
            )
        ) {

            health.checks.add(
                new Check(
                    'Tender reference entered',
                    String.isNotBlank(
                        opp.Tender_Reference__c
                    ),
                    'Government and Trust hospitals need a tender or GeM bid number.'
                )
            );
        }

        /*
         * Count how many checks passed
         */
        Integer passed = 0;

        for (Check c : health.checks) {
            if (c.passed) {
                passed++;
            }
        }

        /*
         * Calculate percentage score
         *
         * Example:
         * 4 passed out of 5 checks
         *
         * 4/5 = 80%
         */
        health.score =
            (Integer)Math.round(
                passed * 100.0 /
                health.checks.size()
            );

        /*
         * Determine health status
         *
         * 80+ = Healthy
         * 50-79 = Needs attention
         * <50 = At risk
         */
        health.status =
            health.score >= 80
            ? 'Healthy'
            : (
                health.score >= 50
                ? 'Needs attention'
                : 'At risk'
            );

        return health;
    }
}