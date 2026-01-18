import { LightningElement, track } from 'lwc';

export default class CreateTaskModal extends LightningElement {
    @track subject = '';
    @track dueDate = '';
    @track priority = 'Normal';
    @track notes = '';
    @track isSubmitting = false;

    priorityOptions = [
        { label: 'High', value: 'High' },
        { label: 'Normal', value: 'Normal' },
        { label: 'Low', value: 'Low' }
    ];

    connectedCallback() {
        // Set default due date to 7 days from now
        const defaultDate = new Date();
        defaultDate.setDate(defaultDate.getDate() + 7);
        this.dueDate = defaultDate.toISOString().split('T')[0];
    }

    get isSubmitDisabled() {
        return !this.subject || this.isSubmitting;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleDueDateChange(event) {
        this.dueDate = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }

    handleNotesChange(event) {
        this.notes = event.target.value;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        if (!this.subject) {
            return;
        }

        this.isSubmitting = true;
        
        this.dispatchEvent(new CustomEvent('save', {
            detail: {
                subject: this.subject,
                dueDate: this.dueDate,
                priority: this.priority,
                notes: this.notes
            }
        }));
    }

    // Prevent modal from closing when clicking inside
    handleModalClick(event) {
        event.stopPropagation();
    }
}
