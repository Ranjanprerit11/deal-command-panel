# Deal Command Panel

[![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?style=flat&logo=salesforce&logoColor=white)](https://salesforce.com)
[![Lightning Web Components](https://img.shields.io/badge/LWC-Lightning%20Web%20Components-00A1E0)](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat&logo=openai&logoColor=white)](https://openai.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A powerful Salesforce Lightning Web Component that gives sales reps a comprehensive "command panel" to diagnose deal health and execute next actions quickly — right from the Opportunity record page.

---

## Features

- **Health Scoring** — Deterministic health score (0-100) based on multiple configurable signals
- **Deal Signals** — Visual indicators for Stage Age, Activity Gap, Close Date Drift, Stakeholders, and Next Step
- **Action Checklist** — Automatically generated recommendations based on deal health
- **Quick Actions** — Create tasks, log calls, update next steps directly from the panel
- **AI Assist** — Get AI-powered risk explanations and email drafts using OpenAI

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [OpenAI Integration](#openai-integration)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Installation

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) (`sf` command)
- A Salesforce org (Developer Edition, Sandbox, or Trailhead Playground)
- [Node.js](https://nodejs.org/) v18+ (for running Jest tests)

### Quick Deploy

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/deal-command-panel.git
cd deal-command-panel

# Authenticate with your Salesforce org
sf org login web --set-default --alias myorg

# Deploy to your org
sf project deploy start --target-org myorg
```

### Add to Opportunity Page

1. Navigate to any **Opportunity** record
2. Click **gear icon (⚙️) > Edit Page**
3. Drag **Deal Command Panel** from Custom components onto the page
4. Click **Save > Activate > Assign as Org Default > Save**
5. Click **Back** to view the component

### Enable Field History Tracking (Recommended)

For accurate Stage Age and Close Date Drift calculations:

1. Go to **Setup > Object Manager > Opportunity > Fields & Relationships**
2. Click **Set History Tracking**
3. Enable tracking for `Stage` and `Close Date`
4. Click **Save**

> **Note**: The component works without Field History Tracking but uses fallback calculations.

---

## Configuration

### Health Score Weights

Customize the health scoring via **Custom Metadata**:

1. Go to **Setup > Custom Metadata Types**
2. Click **Manage Records** next to **Deal Health Weight**
3. Edit or add records to customize thresholds and points

#### Default Scoring Rules

| Signal | Condition | Points |
|--------|-----------|--------|
| Activity Gap | ≤ 7 days | 25 |
| Activity Gap | 8-14 days | 15 |
| Activity Gap | 15-30 days | 5 |
| Activity Gap | > 30 days | 0 |
| Stage Age | ≤ 14 days | 20 |
| Stage Age | 15-30 days | 10 |
| Stage Age | > 30 days | 0 |
| Close Date Drift | No drift | 20 |
| Close Date Drift | 1 push | 10 |
| Close Date Drift | ≥ 2 pushes | 0 |
| Stakeholders | ≥ 2 contacts | 15 |
| Stakeholders | 1 contact | 8 |
| Stakeholders | 0 contacts | 0 |
| Next Step | Defined | 20 |
| Next Step | Empty | 0 |

#### Health Labels

| Score | Label | Badge Color |
|-------|-------|-------------|
| ≥ 75 | Healthy | Green |
| 50-74 | Watch | Yellow |
| < 50 | At Risk | Red |

---

## OpenAI Integration

The AI Assist feature provides intelligent deal analysis and email drafting powered by OpenAI.

### Setup

#### 1. Get Your OpenAI API Key

1. Go to [platform.openai.com](https://platform.openai.com)
2. Navigate to **API Keys**
3. Click **Create new secret key**
4. Copy the key (starts with `sk-`)

#### 2. Configure in Salesforce

1. Go to **Setup > Custom Settings**
2. Find **OpenAI Settings** → click **Manage**
3. Click **New** under "Default Organization Level Value"
4. Fill in:
   - **API Key**: Your OpenAI API key
   - **Model**: `gpt-4o-mini` (recommended)
   - **Endpoint**: `https://api.openai.com/v1/chat/completions`
5. Click **Save**

### Supported Models

| Model | Quality | Speed | Cost |
|-------|---------|-------|------|
| `gpt-4o-mini` | Good | Fast | $ |
| `gpt-4o` | Excellent | Medium | $$ |
| `gpt-4-turbo` | Excellent | Medium | $$$ |

> **Demo Mode**: The component works without OpenAI configuration using built-in mock responses. A badge indicates the current mode.

---

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── DealPanelService.cls        # Main service class
│   ├── DealPanelServiceTest.cls    # Service tests
│   ├── DealHealthCalculator.cls    # Health scoring logic
│   ├── DealPanelAI.cls             # OpenAI integration
│   ├── DealPanelAITest.cls         # AI service tests
│   └── DealPanelDTO.cls            # Data transfer objects
├── lwc/
│   ├── dealCommandPanel/           # Main container component
│   ├── dealHealthBadge/            # Health status badge
│   ├── dealSignalCard/             # Individual signal display
│   ├── dealChecklist/              # Action checklist
│   ├── dealQuickActions/           # Quick action buttons
│   ├── dealAiAssist/               # AI assist section
│   ├── createTaskModal/            # Task creation modal
│   └── logCallModal/               # Log call modal
├── customMetadata/                 # Health weight configurations
├── objects/
│   ├── Deal_Health_Weight__mdt/    # Custom metadata type
│   └── OpenAI_Settings__c/         # OpenAI configuration
└── remoteSiteSettings/             # External API access
```

---

## Testing

### Apex Tests

```bash
sf apex run test --target-org myorg --code-coverage --result-format human --wait 10
```

### LWC Jest Tests

```bash
# Install dependencies
npm install

# Run tests
npm test

# Run with coverage
npm run test:unit:coverage
```

---

## API Reference

### DealPanelService

| Method | Description |
|--------|-------------|
| `getPanelData(opportunityId)` | Returns all panel data including health score and checklist |
| `createTask(opportunityId, subject, dueDate, priority, notes)` | Creates a task linked to the opportunity |
| `logCall(opportunityId, subject, notes, callResult)` | Logs a completed call activity |
| `updateNextStep(opportunityId, nextStepText)` | Updates the opportunity's NextStep field |
| `buildAIContext(opportunityId)` | Builds context payload for AI requests |

### DealPanelAI

| Method | Description |
|--------|-------------|
| `isOpenAIConfigured()` | Returns true if OpenAI API key is configured |
| `explainRisk(opportunityId, contextPayload)` | Gets AI-powered risk explanation |
| `draftEmail(opportunityId, tone, goal, contextPayload)` | Generates AI email draft |
| `getMockRiskExplanation(opportunityId)` | Returns mock risk explanation (demo mode) |
| `getMockEmailDraft(opportunityId, tone, goal)` | Returns mock email draft (demo mode) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Opportunity not found" | Ensure user has read access to the Opportunity record |
| Stage Age shows days since creation | Enable Field History Tracking for StageName |
| Close Date Drift always 0 | Enable Field History Tracking for CloseDate |
| AI shows "Demo Mode" | Configure OpenAI API key in Custom Settings |
| AI returns errors | Check API key validity and OpenAI account credits |
| Component not visible | Verify deployment succeeded; check you're on an Opportunity page |

---

## Checklist Rules

The component automatically generates checklist items:

| Condition | Checklist Item | Action |
|-----------|----------------|--------|
| Activity Gap > 14 days | "Log a touchpoint" | Opens Log Call modal |
| NextStep empty | "Confirm next step" | Opens Next Step editor |
| Stage Age > 30 days | "Review stage aging" | Info only |
| Contact Roles < 2 | "Add stakeholders" | Links to Contact Roles |
| Close Date Drift ≥ 2 | "Reconfirm close date" | Info only |

---

## Security

- All Apex classes use `with sharing` to enforce record-level security
- CRUD/FLS permissions are checked before DML operations
- OpenAI API key stored in protected Custom Setting
- AI context contains only non-sensitive summary data (no PII)

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Built with [Salesforce Lightning Web Components](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- AI powered by [OpenAI](https://openai.com)
