import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getPanelData from '@salesforce/apex/DealPanelService.getPanelData';
import createTask from '@salesforce/apex/DealPanelService.createTask';
import logCall from '@salesforce/apex/DealPanelService.logCall';
import updateNextStep from '@salesforce/apex/DealPanelService.updateNextStep';

import OPPORTUNITY_NAME from '@salesforce/schema/Opportunity.Name';
import OPPORTUNITY_AMOUNT from '@salesforce/schema/Opportunity.Amount';
import OPPORTUNITY_STAGE from '@salesforce/schema/Opportunity.StageName';
import OPPORTUNITY_CLOSE_DATE from '@salesforce/schema/Opportunity.CloseDate';
import OPPORTUNITY_NEXT_STEP from '@salesforce/schema/Opportunity.NextStep';

const OPPORTUNITY_FIELDS = [
    OPPORTUNITY_NAME,
    OPPORTUNITY_AMOUNT,
    OPPORTUNITY_STAGE,
    OPPORTUNITY_CLOSE_DATE,
    OPPORTUNITY_NEXT_STEP
];

export default class DealCommandPanel extends LightningElement {
    @api recordId;
    
    @track panelData;
    @track isLoading = true;
    @track error;
    
    // Modal states
    @track showTaskModal = false;
    @track showCallModal = false;
    @track isEditingNextStep = false;
    @track nextStepValue = '';
    
    // AI section state
    @track isAiSectionExpanded = false;
    
    // Wired results for refresh
    wiredPanelDataResult;
    wiredOpportunityResult;

    @wire(getRecord, { recordId: '$recordId', fields: OPPORTUNITY_FIELDS })
    wiredOpportunity(result) {
        this.wiredOpportunityResult = result;
        if (result.data) {
            this.nextStepValue = getFieldValue(result.data, OPPORTUNITY_NEXT_STEP) || '';
        }
    }

    @wire(getPanelData, { opportunityId: '$recordId' })
    wiredPanelData(result) {
        this.wiredPanelDataResult = result;
        this.isLoading = false;
        
        if (result.data) {
            this.panelData = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this.reduceErrors(result.error);
            this.panelData = undefined;
        }
    }

    // Computed properties for template
    get opportunityName() {
        return this.panelData?.oppSummary?.name || '';
    }

    get opportunityAmount() {
        const amount = this.panelData?.oppSummary?.amount;
        if (amount) {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD',
                minimumFractionDigits: 0,
                maximumFractionDigits: 0
            }).format(amount);
        }
        return '$0';
    }

    get opportunityStage() {
        return this.panelData?.oppSummary?.stageName || '';
    }

    get opportunityCloseDate() {
        const closeDate = this.panelData?.oppSummary?.closeDate;
        if (closeDate) {
            return new Date(closeDate).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
        }
        return '';
    }

    get healthScore() {
        return this.panelData?.healthScore || 0;
    }

    get healthLabel() {
        return this.panelData?.healthLabel || 'Unknown';
    }

    get hasError() {
        return !!this.error;
    }

    get hasData() {
        return !!this.panelData;
    }

    // Signal data for cards
    get signals() {
        if (!this.panelData) return [];
        
        return [
            {
                id: 'stageAge',
                name: 'Stage Age',
                value: this.panelData.stageAgeDays !== null ? `${this.panelData.stageAgeDays} days` : 'N/A',
                icon: 'utility:clock',
                severity: this.getStageAgeSeverity(this.panelData.stageAgeDays)
            },
            {
                id: 'activityGap',
                name: 'Activity Gap',
                value: this.panelData.activityGapDays !== null ? `${this.panelData.activityGapDays} days` : 'No activities',
                icon: 'utility:activity',
                severity: this.getActivityGapSeverity(this.panelData.activityGapDays)
            },
            {
                id: 'closeDateDrift',
                name: 'Close Date Drift',
                value: this.panelData.closeDatePushCount > 0 ? `${this.panelData.closeDatePushCount} push(es)` : 'No drift',
                icon: 'utility:date_input',
                severity: this.getCloseDateDriftSeverity(this.panelData.closeDatePushCount)
            },
            {
                id: 'stakeholders',
                name: 'Stakeholders',
                value: `${this.panelData.contactRoleCount || 0} contact(s)`,
                icon: 'utility:people',
                severity: this.getStakeholderSeverity(this.panelData.contactRoleCount)
            },
            {
                id: 'nextStep',
                name: 'Next Step',
                value: this.panelData.nextStepMissing ? 'Missing' : 'Present',
                icon: 'utility:forward',
                severity: this.panelData.nextStepMissing ? 'high' : 'low'
            }
        ];
    }

    get checklistItems() {
        return this.panelData?.checklistItems || [];
    }

    get hasChecklistItems() {
        return this.checklistItems.length > 0;
    }

    get recentActivities() {
        return this.panelData?.recentActivities || [];
    }

    get hasRecentActivities() {
        return this.recentActivities.length > 0;
    }

    get aiSectionIcon() {
        return this.isAiSectionExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Severity calculation methods
    getStageAgeSeverity(days) {
        if (days === null) return 'neutral';
        if (days <= 14) return 'low';
        if (days <= 30) return 'medium';
        return 'high';
    }

    getActivityGapSeverity(days) {
        if (days === null) return 'high';
        if (days <= 7) return 'low';
        if (days <= 14) return 'medium';
        return 'high';
    }

    getCloseDateDriftSeverity(count) {
        if (!count || count === 0) return 'low';
        if (count === 1) return 'medium';
        return 'high';
    }

    getStakeholderSeverity(count) {
        if (count >= 2) return 'low';
        if (count === 1) return 'medium';
        return 'high';
    }

    // Event handlers
    handleTaskModalOpen() {
        this.showTaskModal = true;
    }

    handleTaskModalClose() {
        this.showTaskModal = false;
    }

    handleCallModalOpen() {
        this.showCallModal = true;
    }

    handleCallModalClose() {
        this.showCallModal = false;
    }

    handleEditNextStep() {
        this.isEditingNextStep = true;
    }

    handleNextStepChange(event) {
        this.nextStepValue = event.target.value;
    }

    handleCancelNextStepEdit() {
        this.isEditingNextStep = false;
        // Reset to original value
        if (this.wiredOpportunityResult?.data) {
            this.nextStepValue = getFieldValue(this.wiredOpportunityResult.data, OPPORTUNITY_NEXT_STEP) || '';
        }
    }

    async handleSaveNextStep() {
        try {
            await updateNextStep({
                opportunityId: this.recordId,
                nextStepText: this.nextStepValue
            });
            
            this.isEditingNextStep = false;
            this.showToast('Success', 'Next step updated successfully', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
        }
    }

    async handleTaskCreated(event) {
        const { subject, dueDate, priority, notes } = event.detail;
        
        try {
            await createTask({
                opportunityId: this.recordId,
                subject,
                dueDate,
                priority,
                notes
            });
            
            this.showTaskModal = false;
            this.showToast('Success', 'Task created successfully', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
        }
    }

    async handleCallLogged(event) {
        const { subject, notes, callResult } = event.detail;
        
        try {
            await logCall({
                opportunityId: this.recordId,
                subject,
                notes,
                callResult
            });
            
            this.showCallModal = false;
            this.showToast('Success', 'Call logged successfully', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
        }
    }

    handleChecklistAction(event) {
        const { actionType } = event.detail;
        
        switch (actionType) {
            case 'logCall':
                this.showCallModal = true;
                break;
            case 'updateNextStep':
                this.isEditingNextStep = true;
                break;
            case 'createTask':
                this.showTaskModal = true;
                break;
            case 'externalLink':
                // Navigate to contact roles related list
                this.navigateToContactRoles();
                break;
            default:
                // Info type - just show message
                break;
        }
    }

    navigateToContactRoles() {
        // Navigate to the opportunity's contact roles related list
        window.open(`/${this.recordId}?tab=Contact+Roles`, '_blank');
    }

    toggleAiSection() {
        this.isAiSectionExpanded = !this.isAiSectionExpanded;
    }

    async refreshData() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredPanelDataResult),
                refreshApex(this.wiredOpportunityResult)
            ]);
        } catch (error) {
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return 'An unknown error occurred';
    }
}
