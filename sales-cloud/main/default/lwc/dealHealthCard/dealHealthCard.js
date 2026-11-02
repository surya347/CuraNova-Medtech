import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getHealth from "@salesforce/apex/DealHealthController.getHealth";

const STATUS_CLASS = {
  "Healthy": "slds-text-color_success",
  "Needs attention": "status-warning",
  "At risk": "slds-text-color_error"
};

export default class DealHealthCard extends LightningElement {
  // Filled in by the record page with the Opportunity's Id
  @api recordId;

  health;
  error;
  wiredResult;

  // Calls the Apex method whenever recordId is set or changes
  @wire(getHealth, { opportunityId: "$recordId" })
  wiredHealth(result) {
    this.wiredResult = result;
    if (result.data) {
      this.health = result.data;
      this.error = undefined;
    } else if (result.error) {
      this.health = undefined;
      this.error = result.error.body
        ? result.error.body.message
        : "Could not load deal health.";
    }
  }

  get statusClass() {
    return "slds-text-title_bold " + (STATUS_CLASS[this.health.status] || "");
  }

  get checks() {
    return this.health.checks.map((check, index) => ({
      ...check,
      key: index,
      icon: check.passed ? "utility:success" : "utility:warning",
      variant: check.passed ? "success" : "warning",
      showTip: !check.passed
    }));
  }

  // Apex results are cached, so the refresh button asks for fresh data
  handleRefresh() {
    return refreshApex(this.wiredResult);
  }
}
