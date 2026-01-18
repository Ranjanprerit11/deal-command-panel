/**
 * @description Main service class for the Deal Command Panel
 * Provides data retrieval and action methods for the LWC component
 */
public with sharing class DealPanelService {
    
    private static final Integer RECENT_ACTIVITIES_LIMIT = 5;
    
    /**
     * @description Get all panel data for an opportunity
     * @param opportunityId The opportunity record ID
     * @return PanelData containing all metrics, health score, and checklist items
     */
    @AuraEnabled(cacheable=true)
    public static DealPanelDTO.PanelData getPanelData(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required');
        }
        
        DealPanelDTO.PanelData panelData = new DealPanelDTO.PanelData();
        
        // 1. Query Opportunity fields
        Opportunity opp = queryOpportunity(opportunityId);
        panelData.oppSummary = new DealPanelDTO.OppSummary(opp);
        
        // 2. Calculate stage age from field history (graceful fallback)
        panelData.stageAgeDays = calculateStageAge(opportunityId, opp.CreatedDate);
        
        // 3. Calculate close date push count from field history (graceful fallback)
        panelData.closeDatePushCount = calculateCloseDatePushCount(opportunityId);
        
        // 4. Calculate activity gap from completed tasks (graceful fallback)
        panelData.activityGapDays = calculateActivityGap(opportunityId);
        
        // 5. Get contact role count (graceful fallback)
        panelData.contactRoleCount = getContactRoleCount(opportunityId);
        
        // 6. Check if NextStep is present
        panelData.nextStepMissing = String.isBlank(opp.NextStep);
        
        // 7. Calculate health score
        DealPanelDTO.HealthResult healthResult = DealHealthCalculator.calculateHealth(
            panelData.activityGapDays,
            panelData.stageAgeDays,
            panelData.closeDatePushCount,
            panelData.contactRoleCount,
            !panelData.nextStepMissing
        );
        panelData.healthScore = healthResult.score;
        panelData.healthLabel = healthResult.label;
        
        // 8. Generate checklist items
        panelData.checklistItems = DealHealthCalculator.generateChecklist(
            panelData.activityGapDays,
            panelData.stageAgeDays,
            panelData.closeDatePushCount,
            panelData.contactRoleCount,
            !panelData.nextStepMissing
        );
        
        // 9. Get recent activities (graceful fallback)
        panelData.recentActivities = getRecentActivities(opportunityId);
        
        return panelData;
    }
    
    /**
     * @description Create a task related to the opportunity
     * @param opportunityId The opportunity record ID
     * @param subject Task subject
     * @param dueDate Task due date
     * @param priority Task priority (High, Normal, Low)
     * @param notes Task description/notes
     * @return The created Task ID
     */
    @AuraEnabled
    public static Id createTask(Id opportunityId, String subject, Date dueDate, String priority, String notes) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Task subject is required');
        }
        
        // CRUD check
        if (!Schema.sObjectType.Task.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create tasks');
        }
        
        Task newTask = new Task(
            WhatId = opportunityId,
            Subject = subject,
            ActivityDate = dueDate != null ? dueDate : Date.today().addDays(7),
            Priority = String.isNotBlank(priority) ? priority : 'Normal',
            Description = notes,
            Status = 'Not Started'
        );
        
        try {
            insert newTask;
            return newTask.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating task: ' + e.getMessage());
        }
    }
    
    /**
     * @description Log a call activity for the opportunity
     * @param opportunityId The opportunity record ID
     * @param subject Call subject
     * @param notes Call notes/description
     * @param callResult Result of the call
     * @return The created Task ID
     */
    @AuraEnabled
    public static Id logCall(Id opportunityId, String subject, String notes, String callResult) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Call subject is required');
        }
        
        // CRUD check
        if (!Schema.sObjectType.Task.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create tasks');
        }
        
        Task callTask = new Task(
            WhatId = opportunityId,
            Subject = subject,
            Description = notes,
            Type = 'Call',
            TaskSubtype = 'Call',
            Status = 'Completed',
            ActivityDate = Date.today(),
            CallType = 'Outbound',
            CallDisposition = callResult
        );
        
        try {
            insert callTask;
            return callTask.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error logging call: ' + e.getMessage());
        }
    }
    
    /**
     * @description Update the NextStep field on the opportunity
     * @param opportunityId The opportunity record ID
     * @param nextStepText The new NextStep value
     */
    @AuraEnabled
    public static void updateNextStep(Id opportunityId, String nextStepText) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required');
        }
        
        // CRUD/FLS checks
        if (!Schema.sObjectType.Opportunity.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update opportunities');
        }
        if (!Schema.sObjectType.Opportunity.fields.NextStep.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update the NextStep field');
        }
        
        Opportunity opp = new Opportunity(
            Id = opportunityId,
            NextStep = nextStepText
        );
        
        try {
            update opp;
        } catch (DmlException e) {
            throw new AuraHandledException('Error updating NextStep: ' + e.getMessage());
        }
    }
    
    /**
     * @description Query opportunity with required fields
     */
    private static Opportunity queryOpportunity(Id opportunityId) {
        // Query without WITH SECURITY_ENFORCED - rely on with sharing instead
        List<Opportunity> opps = [
            SELECT Id, Name, Amount, StageName, CloseDate, NextStep, 
                   CreatedDate, LastModifiedDate, Owner.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        
        if (opps.isEmpty()) {
            throw new AuraHandledException('Opportunity not found');
        }
        
        return opps[0];
    }
    
    /**
     * @description Calculate days in current stage using field history
     * Returns days since creation if field history is not available
     */
    private static Integer calculateStageAge(Id opportunityId, Datetime createdDate) {
        try {
            // Query the most recent StageName change from field history
            List<OpportunityFieldHistory> stageHistory = [
                SELECT CreatedDate
                FROM OpportunityFieldHistory
                WHERE OpportunityId = :opportunityId
                AND Field = 'StageName'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Datetime stageStartDate;
            if (!stageHistory.isEmpty()) {
                stageStartDate = stageHistory[0].CreatedDate;
            } else {
                // No history means it's been in the same stage since creation
                stageStartDate = createdDate;
            }
            
            return stageStartDate.date().daysBetween(Date.today());
        } catch (Exception e) {
            // Field history not available - calculate from creation date
            System.debug('Field history not available for Stage: ' + e.getMessage());
            return createdDate.date().daysBetween(Date.today());
        }
    }
    
    /**
     * @description Count number of times CloseDate was pushed (moved to later date)
     * Returns 0 if field history is not available
     */
    private static Integer calculateCloseDatePushCount(Id opportunityId) {
        try {
            List<OpportunityFieldHistory> closeDateHistory = [
                SELECT OldValue, NewValue, CreatedDate
                FROM OpportunityFieldHistory
                WHERE OpportunityId = :opportunityId
                AND Field = 'CloseDate'
                ORDER BY CreatedDate ASC
            ];
            
            Integer pushCount = 0;
            for (OpportunityFieldHistory history : closeDateHistory) {
                if (history.OldValue != null && history.NewValue != null) {
                    Date oldDate = Date.valueOf(String.valueOf(history.OldValue));
                    Date newDate = Date.valueOf(String.valueOf(history.NewValue));
                    if (newDate > oldDate) {
                        pushCount++;
                    }
                }
            }
            
            return pushCount;
        } catch (Exception e) {
            // Field history not available
            System.debug('Field history not available for CloseDate: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * @description Calculate days since last completed activity
     * Returns null if no activities or access denied
     */
    private static Integer calculateActivityGap(Id opportunityId) {
        try {
            List<Task> completedTasks = [
                SELECT ActivityDate, CompletedDateTime, CreatedDate
                FROM Task
                WHERE WhatId = :opportunityId
                AND Status = 'Completed'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (completedTasks.isEmpty()) {
                // No completed activities - return null to indicate no data
                return null;
            }
            
            Task lastTask = completedTasks[0];
            Date lastActivityDate;
            
            // Try CompletedDateTime first, then ActivityDate, then CreatedDate
            if (lastTask.CompletedDateTime != null) {
                lastActivityDate = lastTask.CompletedDateTime.date();
            } else if (lastTask.ActivityDate != null) {
                lastActivityDate = lastTask.ActivityDate;
            } else if (lastTask.CreatedDate != null) {
                lastActivityDate = lastTask.CreatedDate.date();
            }
            
            if (lastActivityDate == null) {
                return null;
            }
            
            return lastActivityDate.daysBetween(Date.today());
        } catch (Exception e) {
            System.debug('Error calculating activity gap: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Get count of contact roles on the opportunity
     * Returns 0 if access denied
     */
    private static Integer getContactRoleCount(Id opportunityId) {
        try {
            return [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :opportunityId
            ];
        } catch (Exception e) {
            System.debug('Error getting contact role count: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * @description Get recent completed activities
     * Returns empty list if access denied
     */
    private static List<DealPanelDTO.ActivitySummary> getRecentActivities(Id opportunityId) {
        List<DealPanelDTO.ActivitySummary> activities = new List<DealPanelDTO.ActivitySummary>();
        
        try {
            List<Task> recentTasks = [
                SELECT Id, Subject, ActivityDate, Type, Status
                FROM Task
                WHERE WhatId = :opportunityId
                AND Status = 'Completed'
                ORDER BY ActivityDate DESC
                LIMIT :RECENT_ACTIVITIES_LIMIT
            ];
            
            for (Task t : recentTasks) {
                activities.add(new DealPanelDTO.ActivitySummary(t));
            }
        } catch (Exception e) {
            System.debug('Error getting recent activities: ' + e.getMessage());
        }
        
        return activities;
    }
    
    /**
     * @description Build AI context payload (non-sensitive data only)
     */
    @AuraEnabled
    public static DealPanelDTO.AIContext buildAIContext(Id opportunityId) {
        DealPanelDTO.PanelData panelData = getPanelData(opportunityId);
        
        DealPanelDTO.AIContext context = new DealPanelDTO.AIContext();
        context.stageName = panelData.oppSummary.stageName;
        context.stageAgeDays = panelData.stageAgeDays;
        context.activityGapDays = panelData.activityGapDays;
        context.closeDatePushCount = panelData.closeDatePushCount;
        context.contactRoleCount = panelData.contactRoleCount;
        context.hasNextStep = !panelData.nextStepMissing;
        context.healthScore = panelData.healthScore;
        context.healthLabel = panelData.healthLabel;
        
        // Add recent activity subjects (non-sensitive)
        for (DealPanelDTO.ActivitySummary activity : panelData.recentActivities) {
            if (String.isNotBlank(activity.subject)) {
                context.recentActivitySubjects.add(activity.subject);
            }
        }
        
        return context;
    }
}
