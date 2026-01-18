import { createElement } from 'lwc';
import DealChecklist from 'c/dealChecklist';

describe('c-deal-checklist', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    const MOCK_CHECKLIST_ITEMS = [
        {
            id: 'activity_gap',
            label: 'Log a touchpoint',
            severity: 'high',
            actionType: 'logCall'
        },
        {
            id: 'next_step',
            label: 'Confirm next step',
            severity: 'high',
            actionType: 'updateNextStep'
        },
        {
            id: 'stage_aging',
            label: 'Review stage aging',
            severity: 'medium',
            actionType: 'info'
        }
    ];

    it('renders checklist items', () => {
        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = MOCK_CHECKLIST_ITEMS;
        document.body.appendChild(element);

        const listItems = element.shadowRoot.querySelectorAll('li');
        expect(listItems.length).toBe(3);
    });

    it('displays empty state when no items', () => {
        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = [];
        document.body.appendChild(element);

        const emptyMessage = element.shadowRoot.querySelector('.slds-text-align_center');
        expect(emptyMessage).not.toBeNull();
    });

    it('shows fix button for actionable items', () => {
        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = [MOCK_CHECKLIST_ITEMS[0]];
        document.body.appendChild(element);

        const button = element.shadowRoot.querySelector('lightning-button');
        expect(button).not.toBeNull();
        expect(button.label).toBe('Log Call');
    });

    it('shows badge for info items', () => {
        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = [MOCK_CHECKLIST_ITEMS[2]];
        document.body.appendChild(element);

        const badge = element.shadowRoot.querySelector('lightning-badge');
        expect(badge).not.toBeNull();
    });

    it('dispatches checklistaction event on fix click', () => {
        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = [MOCK_CHECKLIST_ITEMS[0]];
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('checklistaction', handler);

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail.actionType).toBe('logCall');
        expect(handler.mock.calls[0][0].detail.itemId).toBe('activity_gap');
    });

    it('applies correct severity styling', () => {
        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = MOCK_CHECKLIST_ITEMS;
        document.body.appendChild(element);

        const highSeverityItem = element.shadowRoot.querySelector('.severity-high');
        const mediumSeverityItem = element.shadowRoot.querySelector('.severity-medium');
        
        expect(highSeverityItem).not.toBeNull();
        expect(mediumSeverityItem).not.toBeNull();
    });

    it('displays correct fix button labels', () => {
        const items = [
            { id: '1', label: 'Test', severity: 'high', actionType: 'logCall' },
            { id: '2', label: 'Test', severity: 'high', actionType: 'updateNextStep' },
            { id: '3', label: 'Test', severity: 'high', actionType: 'createTask' },
            { id: '4', label: 'Test', severity: 'high', actionType: 'externalLink' }
        ];

        const element = createElement('c-deal-checklist', {
            is: DealChecklist
        });
        element.items = items;
        document.body.appendChild(element);

        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        const labels = Array.from(buttons).map(btn => btn.label);
        
        expect(labels).toContain('Log Call');
        expect(labels).toContain('Update');
        expect(labels).toContain('Create Task');
        expect(labels).toContain('Add');
    });
});
