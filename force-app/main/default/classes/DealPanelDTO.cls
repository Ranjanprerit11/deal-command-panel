/**
 * @description Data Transfer Objects for the Deal Command Panel
 * Contains all wrapper classes used for data transfer between Apex and LWC
 */
public class DealPanelDTO {
    
    /**
     * @description Main panel data container returned by getPanelData
     */
    public class PanelData {
        @AuraEnabled public OppSummary oppSummary;
        @AuraEnabled public Integer stageAgeDays;
        @AuraEnabled public Integer activityGapDays;
        @AuraEnabled public Integer closeDatePushCount;
        @AuraEnabled public Integer contactRoleCount;
        @AuraEnabled public Boolean nextStepMissing;
        @AuraEnabled public Integer healthScore;
        @AuraEnabled public String healthLabel;
        @AuraEnabled public List<ChecklistItem> checklistItems;
        @AuraEnabled public List<ActivitySummary> recentActivities;
        
        public PanelData() {
            this.checklistItems = new List<ChecklistItem>();
            this.recentActivities = new List<ActivitySummary>();
        }
    }
    
    /**
     * @description Opportunity summary data
     */
    public class OppSummary {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String stageName;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String nextStep;
        @AuraEnabled public String ownerName;
        
        public OppSummary() {}
        
        public OppSummary(Opportunity opp) {
            this.opportunityId = opp.Id;
            this.name = opp.Name;
            this.amount = opp.Amount;
            this.stageName = opp.StageName;
            this.closeDate = opp.CloseDate;
            this.nextStep = opp.NextStep;
            this.ownerName = opp.Owner != null ? opp.Owner.Name : null;
        }
    }
    
    /**
     * @description Checklist item for action recommendations
     */
    public class ChecklistItem {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String severity; // 'high', 'medium', 'low'
        @AuraEnabled public String actionType; // 'logCall', 'updateNextStep', 'createTask', 'info', 'externalLink'
        @AuraEnabled public Map<String, Object> defaultPayload;
        @AuraEnabled public Boolean isComplete;
        
        public ChecklistItem() {
            this.defaultPayload = new Map<String, Object>();
            this.isComplete = false;
        }
        
        public ChecklistItem(String id, String label, String severity, String actionType) {
            this();
            this.id = id;
            this.label = label;
            this.severity = severity;
            this.actionType = actionType;
        }
    }
    
    /**
     * @description Activity summary for recent activities display
     */
    public class ActivitySummary {
        @AuraEnabled public Id activityId;
        @AuraEnabled public String subject;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public String activityType;
        @AuraEnabled public String status;
        
        public ActivitySummary() {}
        
        public ActivitySummary(Task t) {
            this.activityId = t.Id;
            this.subject = t.Subject;
            this.activityDate = t.ActivityDate;
            this.activityType = t.Type;
            this.status = t.Status;
        }
    }
    
    /**
     * @description Health calculation result
     */
    public class HealthResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String label;
        @AuraEnabled public Map<String, Integer> componentScores;
        
        public HealthResult() {
            this.componentScores = new Map<String, Integer>();
        }
    }
    
    /**
     * @description AI risk explanation response
     */
    public class RiskExplanation {
        @AuraEnabled public List<String> riskSummary;
        @AuraEnabled public List<String> topNextSteps;
        @AuraEnabled public List<String> questionsToAsk;
        
        public RiskExplanation() {
            this.riskSummary = new List<String>();
            this.topNextSteps = new List<String>();
            this.questionsToAsk = new List<String>();
        }
    }
    
    /**
     * @description AI email draft response
     */
    public class EmailDraft {
        @AuraEnabled public String emailSubject;
        @AuraEnabled public String emailBody;
        
        public EmailDraft() {}
        
        public EmailDraft(String subject, String body) {
            this.emailSubject = subject;
            this.emailBody = body;
        }
    }
    
    /**
     * @description Context payload for AI requests (non-sensitive data only)
     */
    public class AIContext {
        @AuraEnabled public String stageName;
        @AuraEnabled public Integer stageAgeDays;
        @AuraEnabled public Integer activityGapDays;
        @AuraEnabled public Integer closeDatePushCount;
        @AuraEnabled public Integer contactRoleCount;
        @AuraEnabled public Boolean hasNextStep;
        @AuraEnabled public Integer healthScore;
        @AuraEnabled public String healthLabel;
        @AuraEnabled public List<String> recentActivitySubjects;
        
        public AIContext() {
            this.recentActivitySubjects = new List<String>();
        }
    }
}
