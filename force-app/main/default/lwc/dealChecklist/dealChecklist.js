import { LightningElement, api } from 'lwc';

export default class DealChecklist extends LightningElement {
    @api items = [];

    get hasItems() {
        return this.items && this.items.length > 0;
    }

    get processedItems() {
        return this.items.map(item => ({
            ...item,
            iconName: this.getIconForSeverity(item.severity),
            iconVariant: this.getIconVariant(item.severity),
            itemClass: `checklist-item severity-${item.severity}`,
            showFixButton: this.shouldShowFixButton(item.actionType),
            fixButtonLabel: this.getFixButtonLabel(item.actionType)
        }));
    }

    getIconForSeverity(severity) {
        switch (severity) {
            case 'high':
                return 'utility:error';
            case 'medium':
                return 'utility:warning';
            case 'low':
                return 'utility:info';
            default:
                return 'utility:info';
        }
    }

    getIconVariant(severity) {
        switch (severity) {
            case 'high':
                return 'error';
            case 'medium':
                return 'warning';
            default:
                return '';
        }
    }

    shouldShowFixButton(actionType) {
        return actionType !== 'info';
    }

    getFixButtonLabel(actionType) {
        switch (actionType) {
            case 'logCall':
                return 'Log Call';
            case 'updateNextStep':
                return 'Update';
            case 'createTask':
                return 'Create Task';
            case 'externalLink':
                return 'Add';
            default:
                return 'Fix';
        }
    }

    handleFixClick(event) {
        const itemId = event.currentTarget.dataset.id;
        const actionType = event.currentTarget.dataset.action;
        const item = this.items.find(i => i.id === itemId);
        
        this.dispatchEvent(new CustomEvent('checklistaction', {
            detail: {
                itemId,
                actionType,
                defaultPayload: item?.defaultPayload || {}
            }
        }));
    }
}
