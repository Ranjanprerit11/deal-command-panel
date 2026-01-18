/**
 * @description Calculates deal health score based on deterministic rules
 * Uses configurable weights via constants (can be moved to Custom Metadata)
 */
public class DealHealthCalculator {
    
    // Health score thresholds
    public static final Integer HEALTHY_THRESHOLD = 75;
    public static final Integer WATCH_THRESHOLD = 50;
    
    // Health labels
    public static final String LABEL_HEALTHY = 'Healthy';
    public static final String LABEL_WATCH = 'Watch';
    public static final String LABEL_AT_RISK = 'At Risk';
    
    // Activity Gap weights (max 25 points)
    public static final Integer ACTIVITY_GAP_TIER1_DAYS = 7;
    public static final Integer ACTIVITY_GAP_TIER1_POINTS = 25;
    public static final Integer ACTIVITY_GAP_TIER2_DAYS = 14;
    public static final Integer ACTIVITY_GAP_TIER2_POINTS = 15;
    public static final Integer ACTIVITY_GAP_TIER3_DAYS = 30;
    public static final Integer ACTIVITY_GAP_TIER3_POINTS = 5;
    
    // Stage Age weights (max 20 points)
    public static final Integer STAGE_AGE_TIER1_DAYS = 14;
    public static final Integer STAGE_AGE_TIER1_POINTS = 20;
    public static final Integer STAGE_AGE_TIER2_DAYS = 30;
    public static final Integer STAGE_AGE_TIER2_POINTS = 10;
    
    // Close Date Drift weights (max 20 points)
    public static final Integer CLOSE_DATE_NO_DRIFT_POINTS = 20;
    public static final Integer CLOSE_DATE_ONE_PUSH_POINTS = 10;
    
    // Stakeholders weights (max 15 points)
    public static final Integer STAKEHOLDERS_TIER1_COUNT = 2;
    public static final Integer STAKEHOLDERS_TIER1_POINTS = 15;
    public static final Integer STAKEHOLDERS_TIER2_COUNT = 1;
    public static final Integer STAKEHOLDERS_TIER2_POINTS = 8;
    
    // NextStep weights (max 20 points)
    public static final Integer NEXT_STEP_PRESENT_POINTS = 20;
    
    // Checklist thresholds
    public static final Integer CHECKLIST_ACTIVITY_GAP_THRESHOLD = 14;
    public static final Integer CHECKLIST_STAGE_AGE_THRESHOLD = 30;
    public static final Integer CHECKLIST_CLOSE_DATE_DRIFT_THRESHOLD = 2;
    public static final Integer CHECKLIST_STAKEHOLDERS_THRESHOLD = 2;
    
    /**
     * @description Calculate health score based on deal metrics
     * @param activityGapDays Days since last completed activity
     * @param stageAgeDays Days in current stage
     * @param closeDatePushCount Number of times close date was pushed
     * @param contactRoleCount Number of contact roles on opportunity
     * @param hasNextStep Whether NextStep field is populated
     * @return HealthResult containing score, label, and component scores
     */
    public static DealPanelDTO.HealthResult calculateHealth(
        Integer activityGapDays,
        Integer stageAgeDays,
        Integer closeDatePushCount,
        Integer contactRoleCount,
        Boolean hasNextStep
    ) {
        DealPanelDTO.HealthResult result = new DealPanelDTO.HealthResult();
        
        // Calculate component scores
        Integer activityScore = calculateActivityGapScore(activityGapDays);
        Integer stageScore = calculateStageAgeScore(stageAgeDays);
        Integer driftScore = calculateCloseDateDriftScore(closeDatePushCount);
        Integer stakeholderScore = calculateStakeholderScore(contactRoleCount);
        Integer nextStepScore = calculateNextStepScore(hasNextStep);
        
        // Store component scores for transparency
        result.componentScores.put('activityGap', activityScore);
        result.componentScores.put('stageAge', stageScore);
        result.componentScores.put('closeDateDrift', driftScore);
        result.componentScores.put('stakeholders', stakeholderScore);
        result.componentScores.put('nextStep', nextStepScore);
        
        // Calculate total score
        result.score = activityScore + stageScore + driftScore + stakeholderScore + nextStepScore;
        
        // Determine label
        result.label = getHealthLabel(result.score);
        
        return result;
    }
    
    /**
     * @description Calculate activity gap score (max 25 points)
     */
    public static Integer calculateActivityGapScore(Integer activityGapDays) {
        if (activityGapDays == null) {
            return 0;
        }
        
        if (activityGapDays <= ACTIVITY_GAP_TIER1_DAYS) {
            return ACTIVITY_GAP_TIER1_POINTS;
        } else if (activityGapDays <= ACTIVITY_GAP_TIER2_DAYS) {
            return ACTIVITY_GAP_TIER2_POINTS;
        } else if (activityGapDays <= ACTIVITY_GAP_TIER3_DAYS) {
            return ACTIVITY_GAP_TIER3_POINTS;
        }
        return 0;
    }
    
    /**
     * @description Calculate stage age score (max 20 points)
     */
    public static Integer calculateStageAgeScore(Integer stageAgeDays) {
        if (stageAgeDays == null) {
            return STAGE_AGE_TIER1_POINTS; // Default to max if no history
        }
        
        if (stageAgeDays <= STAGE_AGE_TIER1_DAYS) {
            return STAGE_AGE_TIER1_POINTS;
        } else if (stageAgeDays <= STAGE_AGE_TIER2_DAYS) {
            return STAGE_AGE_TIER2_POINTS;
        }
        return 0;
    }
    
    /**
     * @description Calculate close date drift score (max 20 points)
     */
    public static Integer calculateCloseDateDriftScore(Integer closeDatePushCount) {
        if (closeDatePushCount == null || closeDatePushCount == 0) {
            return CLOSE_DATE_NO_DRIFT_POINTS;
        } else if (closeDatePushCount == 1) {
            return CLOSE_DATE_ONE_PUSH_POINTS;
        }
        return 0;
    }
    
    /**
     * @description Calculate stakeholder score (max 15 points)
     */
    public static Integer calculateStakeholderScore(Integer contactRoleCount) {
        if (contactRoleCount == null) {
            return 0;
        }
        
        if (contactRoleCount >= STAKEHOLDERS_TIER1_COUNT) {
            return STAKEHOLDERS_TIER1_POINTS;
        } else if (contactRoleCount >= STAKEHOLDERS_TIER2_COUNT) {
            return STAKEHOLDERS_TIER2_POINTS;
        }
        return 0;
    }
    
    /**
     * @description Calculate next step score (max 20 points)
     */
    public static Integer calculateNextStepScore(Boolean hasNextStep) {
        return (hasNextStep != null && hasNextStep) ? NEXT_STEP_PRESENT_POINTS : 0;
    }
    
    /**
     * @description Get health label based on score
     */
    public static String getHealthLabel(Integer score) {
        if (score >= HEALTHY_THRESHOLD) {
            return LABEL_HEALTHY;
        } else if (score >= WATCH_THRESHOLD) {
            return LABEL_WATCH;
        }
        return LABEL_AT_RISK;
    }
    
    /**
     * @description Generate checklist items based on deal metrics
     */
    public static List<DealPanelDTO.ChecklistItem> generateChecklist(
        Integer activityGapDays,
        Integer stageAgeDays,
        Integer closeDatePushCount,
        Integer contactRoleCount,
        Boolean hasNextStep
    ) {
        List<DealPanelDTO.ChecklistItem> items = new List<DealPanelDTO.ChecklistItem>();
        
        // Activity Gap > 14 days
        if (activityGapDays != null && activityGapDays > CHECKLIST_ACTIVITY_GAP_THRESHOLD) {
            DealPanelDTO.ChecklistItem item = new DealPanelDTO.ChecklistItem(
                'activity_gap',
                'Log a touchpoint',
                activityGapDays > 30 ? 'high' : 'medium',
                'logCall'
            );
            item.defaultPayload.put('suggestedSubject', 'Follow-up call');
            items.add(item);
        }
        
        // NextStep empty
        if (hasNextStep == null || !hasNextStep) {
            DealPanelDTO.ChecklistItem item = new DealPanelDTO.ChecklistItem(
                'next_step',
                'Confirm next step',
                'high',
                'updateNextStep'
            );
            items.add(item);
        }
        
        // Stage Age > 30 days
        if (stageAgeDays != null && stageAgeDays > CHECKLIST_STAGE_AGE_THRESHOLD) {
            DealPanelDTO.ChecklistItem item = new DealPanelDTO.ChecklistItem(
                'stage_aging',
                'Review stage aging',
                stageAgeDays > 45 ? 'high' : 'medium',
                'info'
            );
            item.defaultPayload.put('message', 'This opportunity has been in the current stage for ' + stageAgeDays + ' days. Consider reviewing the deal status.');
            items.add(item);
        }
        
        // Contact Roles < 2
        if (contactRoleCount == null || contactRoleCount < CHECKLIST_STAKEHOLDERS_THRESHOLD) {
            DealPanelDTO.ChecklistItem item = new DealPanelDTO.ChecklistItem(
                'stakeholders',
                'Add stakeholders',
                contactRoleCount == 0 ? 'high' : 'medium',
                'externalLink'
            );
            item.defaultPayload.put('linkType', 'contactRoles');
            items.add(item);
        }
        
        // Close Date Drift >= 2
        if (closeDatePushCount != null && closeDatePushCount >= CHECKLIST_CLOSE_DATE_DRIFT_THRESHOLD) {
            DealPanelDTO.ChecklistItem item = new DealPanelDTO.ChecklistItem(
                'close_date_drift',
                'Reconfirm close date',
                closeDatePushCount > 3 ? 'high' : 'medium',
                'info'
            );
            item.defaultPayload.put('message', 'The close date has been pushed ' + closeDatePushCount + ' times. Consider reconfirming the timeline with the customer.');
            items.add(item);
        }
        
        return items;
    }
}
