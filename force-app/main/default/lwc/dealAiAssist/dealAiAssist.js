import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import isOpenAIConfigured from '@salesforce/apex/DealPanelAI.isOpenAIConfigured';
import explainRisk from '@salesforce/apex/DealPanelAI.explainRisk';
import draftEmail from '@salesforce/apex/DealPanelAI.draftEmail';

export default class DealAiAssist extends LightningElement {
    @api recordId;
    
    @track isLoadingRisk = false;
    @track isLoadingEmail = false;
    @track riskExplanation = null;
    @track emailDraft = null;
    @track error = null;
    @track openAIConfigured = false;
    
    // Email draft options
    @track selectedTone = 'professional';
    @track selectedGoal = 'follow-up';
    @track showEmailOptions = false;

    toneOptions = [
        { label: 'Professional', value: 'professional' },
        { label: 'Friendly', value: 'friendly' },
        { label: 'Urgent', value: 'urgent' }
    ];

    goalOptions = [
        { label: 'Follow-up', value: 'follow-up' },
        { label: 'Check-in', value: 'check-in' },
        { label: 'Proposal', value: 'proposal' },
        { label: 'Next Steps', value: 'next-steps' }
    ];

    @wire(isOpenAIConfigured)
    wiredConfigStatus({ error, data }) {
        if (data !== undefined) {
            this.openAIConfigured = data;
        } else if (error) {
            console.error('Error checking OpenAI config:', error);
            this.openAIConfigured = false;
        }
    }

    get hasRiskExplanation() {
        return this.riskExplanation !== null;
    }

    get hasEmailDraft() {
        return this.emailDraft !== null;
    }

    get hasAnyOutput() {
        return this.hasRiskExplanation || this.hasEmailDraft;
    }

    get showEmptyState() {
        return !this.hasAnyOutput && !this.isLoadingRisk && !this.isLoadingEmail && !this.showEmailOptions;
    }

    get aiModeLabel() {
        return this.openAIConfigured ? 'OpenAI' : 'Demo Mode';
    }

    get aiModeClass() {
        return this.openAIConfigured 
            ? 'ai-mode-badge badge-success' 
            : 'ai-mode-badge badge-warning';
    }

    get riskSummaryItems() {
        return this.riskExplanation?.riskSummary?.map((item, index) => ({
            id: `risk-${index}`,
            text: item
        })) || [];
    }

    get nextStepsItems() {
        return this.riskExplanation?.topNextSteps?.map((item, index) => ({
            id: `step-${index}`,
            text: item
        })) || [];
    }

    get questionsItems() {
        return this.riskExplanation?.questionsToAsk?.map((item, index) => ({
            id: `question-${index}`,
            text: item
        })) || [];
    }

    async handleExplainRisk() {
        this.isLoadingRisk = true;
        this.error = null;
        
        try {
            // Uses real OpenAI if configured, falls back to mock automatically
            this.riskExplanation = await explainRisk({ 
                opportunityId: this.recordId,
                contextPayload: null
            });
        } catch (error) {
            this.error = this.reduceErrors(error);
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoadingRisk = false;
        }
    }

    handleShowEmailOptions() {
        this.showEmailOptions = true;
    }

    handleToneChange(event) {
        this.selectedTone = event.detail.value;
    }

    handleGoalChange(event) {
        this.selectedGoal = event.detail.value;
    }

    async handleDraftEmail() {
        this.isLoadingEmail = true;
        this.error = null;
        
        try {
            // Uses real OpenAI if configured, falls back to mock automatically
            this.emailDraft = await draftEmail({
                opportunityId: this.recordId,
                tone: this.selectedTone,
                goal: this.selectedGoal,
                contextPayload: null
            });
            this.showEmailOptions = false;
        } catch (error) {
            this.error = this.reduceErrors(error);
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoadingEmail = false;
        }
    }

    handleCancelEmailOptions() {
        this.showEmailOptions = false;
    }

    handleEmailSubjectChange(event) {
        if (this.emailDraft) {
            this.emailDraft = {
                ...this.emailDraft,
                emailSubject: event.target.value
            };
        }
    }

    handleEmailBodyChange(event) {
        if (this.emailDraft) {
            this.emailDraft = {
                ...this.emailDraft,
                emailBody: event.target.value
            };
        }
    }

    handleCopyRiskSummary() {
        const text = this.formatRiskExplanationForCopy();
        this.copyToClipboard(text);
    }

    handleCopyEmail() {
        if (this.emailDraft) {
            const text = `Subject: ${this.emailDraft.emailSubject}\n\n${this.emailDraft.emailBody}`;
            this.copyToClipboard(text);
        }
    }

    formatRiskExplanationForCopy() {
        if (!this.riskExplanation) return '';
        
        let text = 'RISK SUMMARY:\n';
        this.riskExplanation.riskSummary?.forEach(item => {
            text += `• ${item}\n`;
        });
        
        text += '\nRECOMMENDED NEXT STEPS:\n';
        this.riskExplanation.topNextSteps?.forEach(item => {
            text += `• ${item}\n`;
        });
        
        text += '\nQUESTIONS TO ASK:\n';
        this.riskExplanation.questionsToAsk?.forEach(item => {
            text += `• ${item}\n`;
        });
        
        return text;
    }

    copyToClipboard(text) {
        navigator.clipboard.writeText(text).then(() => {
            this.showToast('Copied', 'Content copied to clipboard', 'success');
        }).catch(() => {
            this.showToast('Error', 'Failed to copy to clipboard', 'error');
        });
    }

    handleClearRisk() {
        this.riskExplanation = null;
    }

    handleClearEmail() {
        this.emailDraft = null;
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
        return 'An unknown error occurred';
    }
}
