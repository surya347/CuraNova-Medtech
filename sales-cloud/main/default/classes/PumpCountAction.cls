/**
 * Flow Action: Count Pumps on a Deal (Opportunity)
 *
 * Purpose:
 * - Looks at Opportunity Products (OpportunityLineItems)
 * - Finds only products whose Family = 'Infusion Pumps'
 * - Calculates total pump quantity
 * - Creates a readable summary
 * - Returns results back to Flow
 *
 * Example:
 * 60 x Volumetric Pump
 * 20 x Syringe Pump
 *
 * Returns:
 * Pump Count = 80
 * Summary = '60 × Volumetric Pump, 20 × Syringe Pump'
 * 
 * 
 * Flow
    ↓
    Pass Opportunity Id
    ↓
    Apex checks Opportunity Products
    ↓
    Only keeps Family = "Infusion Pumps"
    ↓
    Adds quantities together
    ↓
    Builds description text
    ↓
    Returns:
    Pump Count = 80
    Summary = "60 × Volumetric Pump, 20 × Syringe Pump"
    ↓
    Flow uses values to create Installation Task
 */
public with sharing class PumpCountAction {

    // Product Family we care about
    private static final String PUMP_FAMILY = 'Infusion Pumps';

    /**
     * Input from Flow
     * Flow sends an Opportunity Id
     */
    public class Request {

        @InvocableVariable(
            label='Opportunity ID'
            required=true
        )
        public Id opportunityId;
    }

    /**
     * Output returned to Flow
     */
    public class Result {

        // Total number of pumps
        @InvocableVariable(label='Number of Pumps')
        public Integer pumpCount;

        // Text summary of pumps
        @InvocableVariable(label='Pump Summary')
        public String summary;
    }

    /**
     * Main method called by Flow
     */
    @InvocableMethod(
        label='Count Pumps on Deal'
        description='Counts infusion pumps and creates a summary.'
        category='CuraNova'
    )
    public static List<Result> countPumps(List<Request> requests) {

        // Collect all Opportunity Ids sent by Flow
        Set<Id> opportunityIds = new Set<Id>();

        for (Request r : requests) {
            opportunityIds.add(r.opportunityId);
        }

        /*
         * countByOpp
         * Example:
         * Opp1 -> 80
         * Opp2 -> 120
         */
        Map<Id, Integer> countByOpp = new Map<Id, Integer>();

        /*
         * partsByOpp
         * Example:
         * Opp1 ->
         * [
         *   '60 × Volumetric Pump',
         *   '20 × Syringe Pump'
         * ]
         */
        Map<Id, List<String>> partsByOpp = new Map<Id, List<String>>();

        /**
         * Aggregate Query
         *
         * Groups Opportunity Products by:
         * - Opportunity
         * - Product Name
         *
         * Sums Quantity for each product.
         */
        for (AggregateResult row : [

            SELECT
                OpportunityId oppId,
                Product2.Name productName,
                SUM(Quantity) qty

            FROM OpportunityLineItem

            WHERE OpportunityId IN :opportunityIds
            AND Product2.Family = :PUMP_FAMILY

            GROUP BY OpportunityId, Product2.Name

            ORDER BY Product2.Name
        ]) {

            Id oppId = (Id) row.get('oppId');

            Integer qty =
                ((Decimal) row.get('qty')).intValue();

            // Keep running total of pump quantity
            countByOpp.put(
                oppId,
                (countByOpp.containsKey(oppId)
                    ? countByOpp.get(oppId)
                    : 0)
                + qty
            );

            // Create list if first product for this opportunity
            if (!partsByOpp.containsKey(oppId)) {
                partsByOpp.put(
                    oppId,
                    new List<String>()
                );
            }

            // Add summary line
            // Example: "60 × Volumetric Pump"
            partsByOpp.get(oppId).add(
                qty + ' × ' +
                (String) row.get('productName')
            );
        }

        // Build final response back to Flow
        List<Result> results = new List<Result>();

        for (Request r : requests) {

            Result res = new Result();

            // Total pumps for this Opportunity
            res.pumpCount =
                countByOpp.containsKey(r.opportunityId)
                ? countByOpp.get(r.opportunityId)
                : 0;

            // Summary of pumps
            res.summary =
                partsByOpp.containsKey(r.opportunityId)
                ? String.join(
                    partsByOpp.get(r.opportunityId),
                    ', '
                )
                : 'No pumps on this deal';

            results.add(res);
        }

        return results;
    }
}