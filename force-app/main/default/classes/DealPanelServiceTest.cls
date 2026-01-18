/**
 * @description Test class for DealPanelService and DealHealthCalculator
 */
@isTest
private class DealPanelServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com'
        );
        insert testContact;
        
        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 50000,
            NextStep = 'Schedule demo'
        );
        insert testOpp;
        
        // Create contact role
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = testOpp.Id,
            ContactId = testContact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );
        insert ocr;
        
        // Create completed task
        Task completedTask = new Task(
            WhatId = testOpp.Id,
            Subject = 'Initial Call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-5),
            Type = 'Call'
        );
        insert completedTask;
    }
    
    @isTest
    static void testGetPanelData_Success() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.PanelData result = DealPanelService.getPanelData(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Panel data should not be null');
        System.assertNotEquals(null, result.oppSummary, 'Opp summary should not be null');
        System.assertEquals('Test Opportunity', result.oppSummary.name, 'Opportunity name should match');
        System.assertEquals(50000, result.oppSummary.amount, 'Amount should match');
        System.assertEquals('Prospecting', result.oppSummary.stageName, 'Stage should match');
        System.assertEquals(false, result.nextStepMissing, 'NextStep should be present');
        System.assertEquals(1, result.contactRoleCount, 'Should have 1 contact role');
        System.assertNotEquals(null, result.healthScore, 'Health score should be calculated');
        System.assertNotEquals(null, result.healthLabel, 'Health label should be set');
    }
    
    @isTest
    static void testGetPanelData_NullId() {
        Test.startTest();
        try {
            DealPanelService.getPanelData(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required field');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTask_Success() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        Id taskId = DealPanelService.createTask(
            opp.Id,
            'Follow-up Call',
            Date.today().addDays(7),
            'High',
            'Discuss pricing'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, taskId, 'Task ID should not be null');
        
        Task createdTask = [SELECT Subject, Priority, WhatId FROM Task WHERE Id = :taskId];
        System.assertEquals('Follow-up Call', createdTask.Subject, 'Subject should match');
        System.assertEquals('High', createdTask.Priority, 'Priority should match');
        System.assertEquals(opp.Id, createdTask.WhatId, 'WhatId should be opportunity');
    }
    
    @isTest
    static void testCreateTask_MissingSubject() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        try {
            DealPanelService.createTask(opp.Id, '', Date.today(), 'Normal', 'Notes');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('subject'), 'Should mention subject');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testLogCall_Success() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        Id taskId = DealPanelService.logCall(
            opp.Id,
            'Discovery Call',
            'Discussed requirements',
            'Positive'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, taskId, 'Task ID should not be null');
        
        Task loggedCall = [SELECT Subject, Type, Status FROM Task WHERE Id = :taskId];
        System.assertEquals('Discovery Call', loggedCall.Subject, 'Subject should match');
        System.assertEquals('Call', loggedCall.Type, 'Type should be Call');
        System.assertEquals('Completed', loggedCall.Status, 'Status should be Completed');
    }
    
    @isTest
    static void testUpdateNextStep_Success() {
        Opportunity opp = [SELECT Id, NextStep FROM Opportunity LIMIT 1];
        String newNextStep = 'Send proposal by Friday';
        
        Test.startTest();
        DealPanelService.updateNextStep(opp.Id, newNextStep);
        Test.stopTest();
        
        Opportunity updatedOpp = [SELECT NextStep FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(newNextStep, updatedOpp.NextStep, 'NextStep should be updated');
    }
    
    @isTest
    static void testBuildAIContext() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.AIContext context = DealPanelService.buildAIContext(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, context, 'Context should not be null');
        System.assertEquals('Prospecting', context.stageName, 'Stage name should match');
        System.assertEquals(true, context.hasNextStep, 'Should have next step');
        System.assertNotEquals(null, context.healthScore, 'Health score should be set');
    }
    
    // Health Calculator Tests
    
    @isTest
    static void testCalculateHealth_AllGood() {
        Test.startTest();
        DealPanelDTO.HealthResult result = DealHealthCalculator.calculateHealth(
            5,    // activityGapDays <= 7
            10,   // stageAgeDays <= 14
            0,    // no drift
            3,    // >= 2 stakeholders
            true  // has next step
        );
        Test.stopTest();
        
        System.assertEquals(100, result.score, 'Perfect score should be 100');
        System.assertEquals('Healthy', result.label, 'Label should be Healthy');
    }
    
    @isTest
    static void testCalculateHealth_AtRisk() {
        Test.startTest();
        DealPanelDTO.HealthResult result = DealHealthCalculator.calculateHealth(
            45,   // activityGapDays > 30
            45,   // stageAgeDays > 30
            3,    // >= 2 pushes
            0,    // no stakeholders
            false // no next step
        );
        Test.stopTest();
        
        System.assertEquals(0, result.score, 'Worst score should be 0');
        System.assertEquals('At Risk', result.label, 'Label should be At Risk');
    }
    
    @isTest
    static void testCalculateHealth_Watch() {
        Test.startTest();
        DealPanelDTO.HealthResult result = DealHealthCalculator.calculateHealth(
            10,   // activityGapDays 8-14 = 15 points
            20,   // stageAgeDays 15-30 = 10 points
            1,    // 1 push = 10 points
            1,    // 1 stakeholder = 8 points
            true  // has next step = 20 points
        );
        Test.stopTest();
        
        // Total: 15 + 10 + 10 + 8 + 20 = 63
        System.assertEquals(63, result.score, 'Score should be 63');
        System.assertEquals('Watch', result.label, 'Label should be Watch');
    }
    
    @isTest
    static void testActivityGapScoring() {
        System.assertEquals(25, DealHealthCalculator.calculateActivityGapScore(5), '<=7 days should score 25');
        System.assertEquals(25, DealHealthCalculator.calculateActivityGapScore(7), '7 days should score 25');
        System.assertEquals(15, DealHealthCalculator.calculateActivityGapScore(8), '8 days should score 15');
        System.assertEquals(15, DealHealthCalculator.calculateActivityGapScore(14), '14 days should score 15');
        System.assertEquals(5, DealHealthCalculator.calculateActivityGapScore(15), '15 days should score 5');
        System.assertEquals(5, DealHealthCalculator.calculateActivityGapScore(30), '30 days should score 5');
        System.assertEquals(0, DealHealthCalculator.calculateActivityGapScore(31), '>30 days should score 0');
        System.assertEquals(0, DealHealthCalculator.calculateActivityGapScore(null), 'null should score 0');
    }
    
    @isTest
    static void testStageAgeScoring() {
        System.assertEquals(20, DealHealthCalculator.calculateStageAgeScore(10), '<=14 days should score 20');
        System.assertEquals(20, DealHealthCalculator.calculateStageAgeScore(14), '14 days should score 20');
        System.assertEquals(10, DealHealthCalculator.calculateStageAgeScore(15), '15 days should score 10');
        System.assertEquals(10, DealHealthCalculator.calculateStageAgeScore(30), '30 days should score 10');
        System.assertEquals(0, DealHealthCalculator.calculateStageAgeScore(31), '>30 days should score 0');
        System.assertEquals(20, DealHealthCalculator.calculateStageAgeScore(null), 'null should score 20 (default)');
    }
    
    @isTest
    static void testCloseDateDriftScoring() {
        System.assertEquals(20, DealHealthCalculator.calculateCloseDateDriftScore(0), 'No drift should score 20');
        System.assertEquals(20, DealHealthCalculator.calculateCloseDateDriftScore(null), 'null should score 20');
        System.assertEquals(10, DealHealthCalculator.calculateCloseDateDriftScore(1), '1 push should score 10');
        System.assertEquals(0, DealHealthCalculator.calculateCloseDateDriftScore(2), '>=2 pushes should score 0');
        System.assertEquals(0, DealHealthCalculator.calculateCloseDateDriftScore(5), '5 pushes should score 0');
    }
    
    @isTest
    static void testStakeholderScoring() {
        System.assertEquals(15, DealHealthCalculator.calculateStakeholderScore(2), '>=2 should score 15');
        System.assertEquals(15, DealHealthCalculator.calculateStakeholderScore(5), '5 should score 15');
        System.assertEquals(8, DealHealthCalculator.calculateStakeholderScore(1), '1 should score 8');
        System.assertEquals(0, DealHealthCalculator.calculateStakeholderScore(0), '0 should score 0');
        System.assertEquals(0, DealHealthCalculator.calculateStakeholderScore(null), 'null should score 0');
    }
    
    @isTest
    static void testNextStepScoring() {
        System.assertEquals(20, DealHealthCalculator.calculateNextStepScore(true), 'Present should score 20');
        System.assertEquals(0, DealHealthCalculator.calculateNextStepScore(false), 'Missing should score 0');
        System.assertEquals(0, DealHealthCalculator.calculateNextStepScore(null), 'null should score 0');
    }
    
    @isTest
    static void testGenerateChecklist_AllIssues() {
        Test.startTest();
        List<DealPanelDTO.ChecklistItem> items = DealHealthCalculator.generateChecklist(
            20,   // > 14 days activity gap
            35,   // > 30 days stage age
            3,    // >= 2 pushes
            1,    // < 2 stakeholders
            false // no next step
        );
        Test.stopTest();
        
        System.assertEquals(5, items.size(), 'Should have 5 checklist items');
        
        Set<String> itemIds = new Set<String>();
        for (DealPanelDTO.ChecklistItem item : items) {
            itemIds.add(item.id);
        }
        
        System.assert(itemIds.contains('activity_gap'), 'Should have activity gap item');
        System.assert(itemIds.contains('next_step'), 'Should have next step item');
        System.assert(itemIds.contains('stage_aging'), 'Should have stage aging item');
        System.assert(itemIds.contains('stakeholders'), 'Should have stakeholders item');
        System.assert(itemIds.contains('close_date_drift'), 'Should have close date drift item');
    }
    
    @isTest
    static void testGenerateChecklist_NoIssues() {
        Test.startTest();
        List<DealPanelDTO.ChecklistItem> items = DealHealthCalculator.generateChecklist(
            5,    // <= 14 days activity gap
            10,   // <= 30 days stage age
            0,    // no pushes
            3,    // >= 2 stakeholders
            true  // has next step
        );
        Test.stopTest();
        
        System.assertEquals(0, items.size(), 'Should have no checklist items');
    }
    
    @isTest
    static void testHealthLabels() {
        System.assertEquals('Healthy', DealHealthCalculator.getHealthLabel(100), '100 should be Healthy');
        System.assertEquals('Healthy', DealHealthCalculator.getHealthLabel(75), '75 should be Healthy');
        System.assertEquals('Watch', DealHealthCalculator.getHealthLabel(74), '74 should be Watch');
        System.assertEquals('Watch', DealHealthCalculator.getHealthLabel(50), '50 should be Watch');
        System.assertEquals('At Risk', DealHealthCalculator.getHealthLabel(49), '49 should be At Risk');
        System.assertEquals('At Risk', DealHealthCalculator.getHealthLabel(0), '0 should be At Risk');
    }
}
