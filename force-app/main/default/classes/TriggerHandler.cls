/**
 * Shared trigger framework used by every CuraNova cloud.
 *
 * Pattern: one trigger per object, and the trigger only calls a handler:
 *     trigger OpportunityTrigger on Opportunity (before insert, before update) {
 *         new OpportunityTriggerHandler().run();
 *     }
 * The handler extends this class and overrides only the events it needs.
 */
public virtual class TriggerHandler {

    // Handlers named here are skipped, e.g. during a data load or in a test.
    private static Set<String> bypassedHandlers = new Set<String>();

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    // Sends the current trigger event to the matching method.
    public void run() {
        if (Trigger.operationType == null || bypassedHandlers.contains(getHandlerName())) {
            return;
        }
        switch on Trigger.operationType {
            when BEFORE_INSERT { beforeInsert(); }
            when BEFORE_UPDATE { beforeUpdate(); }
            when BEFORE_DELETE { beforeDelete(); }
            when AFTER_INSERT { afterInsert(); }
            when AFTER_UPDATE { afterUpdate(); }
            when AFTER_DELETE { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    private String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }

    // Override the ones you need in your handler.
    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}
}
