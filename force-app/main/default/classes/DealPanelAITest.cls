/**
 * @description Test class for DealPanelAI with OpenAI integration
 */
@isTest
private class DealPanelAITest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
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
    }
    
    /**
     * @description Create OpenAI Settings for test context
     */
    private static void setupOpenAISettings() {
        OpenAI_Settings__c settings = new OpenAI_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            API_Key__c = 'sk-test-key-12345',
            Model__c = 'gpt-4o-mini',
            Endpoint__c = 'https://api.openai.com/v1/chat/completions'
        );
        insert settings;
    }
    
    /**
     * @description Mock HTTP callout class for successful OpenAI response - Risk
     */
    private class MockOpenAIRiskResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // OpenAI Chat Completions API response format
            Map<String, Object> aiContent = new Map<String, Object>{
                'riskSummary' => new List<String>{
                    'Deal shows signs of stalling due to extended stage duration.',
                    'Limited stakeholder engagement may delay decision-making.'
                },
                'topNextSteps' => new List<String>{
                    'Schedule an executive-level meeting to reinforce value proposition.',
                    'Send ROI analysis document to key decision makers.'
                },
                'questionsToAsk' => new List<String>{
                    'What is your internal timeline for making a final decision?',
                    'Who else from your team should be involved in the evaluation?'
                }
            };
            
            Map<String, Object> responseBody = new Map<String, Object>{
                'id' => 'chatcmpl-123',
                'object' => 'chat.completion',
                'created' => 1677652288,
                'model' => 'gpt-4o-mini',
                'choices' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'index' => 0,
                        'message' => new Map<String, Object>{
                            'role' => 'assistant',
                            'content' => JSON.serialize(aiContent)
                        },
                        'finish_reason' => 'stop'
                    }
                },
                'usage' => new Map<String, Object>{
                    'prompt_tokens' => 100,
                    'completion_tokens' => 150,
                    'total_tokens' => 250
                }
            };
            
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
    
    /**
     * @description Mock HTTP callout class for successful OpenAI response - Email
     */
    private class MockOpenAIEmailResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> aiContent = new Map<String, Object>{
                'emailSubject' => 'Following Up on Our Recent Discussion',
                'emailBody' => 'Hello,\n\nI wanted to follow up on our recent conversation and see if you had any additional questions.\n\nPlease let me know if there\'s anything I can help clarify.\n\nBest regards'
            };
            
            Map<String, Object> responseBody = new Map<String, Object>{
                'id' => 'chatcmpl-456',
                'object' => 'chat.completion',
                'created' => 1677652288,
                'model' => 'gpt-4o-mini',
                'choices' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'index' => 0,
                        'message' => new Map<String, Object>{
                            'role' => 'assistant',
                            'content' => JSON.serialize(aiContent)
                        },
                        'finish_reason' => 'stop'
                    }
                }
            };
            
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
    
    /**
     * @description Mock HTTP callout class for OpenAI error response
     */
    private class MockOpenAIErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'error' => new Map<String, Object>{
                    'message' => 'Invalid API key provided',
                    'type' => 'invalid_request_error',
                    'code' => 'invalid_api_key'
                }
            }));
            return res;
        }
    }
    
    /**
     * @description Mock HTTP callout class for OpenAI rate limit error
     */
    private class MockOpenAIRateLimitResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(429);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'error' => new Map<String, Object>{
                    'message' => 'Rate limit exceeded. Please retry after 20 seconds.',
                    'type' => 'rate_limit_error'
                }
            }));
            return res;
        }
    }
    
    @isTest
    static void testIsOpenAIConfigured_NotConfigured() {
        Test.startTest();
        Boolean result = DealPanelAI.isOpenAIConfigured();
        Test.stopTest();
        
        System.assertEquals(false, result, 'Should return false when not configured');
    }
    
    @isTest
    static void testIsOpenAIConfigured_Configured() {
        setupOpenAISettings();
        
        Test.startTest();
        Boolean result = DealPanelAI.isOpenAIConfigured();
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true when configured');
    }
    
    @isTest
    static void testExplainRisk_WithOpenAI() {
        setupOpenAISettings();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockOpenAIRiskResponse());
        
        Test.startTest();
        DealPanelDTO.RiskExplanation result = DealPanelAI.explainRisk(opp.Id, null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.riskSummary.size(), 'Should have 2 risk items');
        System.assertEquals(2, result.topNextSteps.size(), 'Should have 2 next steps');
        System.assertEquals(2, result.questionsToAsk.size(), 'Should have 2 questions');
    }
    
    @isTest
    static void testExplainRisk_FallbackToMock() {
        // Don't setup OpenAI settings - should fall back to mock
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.RiskExplanation result = DealPanelAI.explainRisk(opp.Id, null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.riskSummary.size() > 0, 'Should have risk summary from mock');
    }
    
    @isTest
    static void testExplainRisk_WithContext() {
        setupOpenAISettings();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Map<String, Object> contextPayload = new Map<String, Object>{
            'stageName' => 'Negotiation',
            'stageAgeDays' => 15,
            'activityGapDays' => 10,
            'closeDatePushCount' => 1,
            'contactRoleCount' => 2,
            'hasNextStep' => true,
            'healthScore' => 75,
            'healthLabel' => 'Healthy',
            'recentActivitySubjects' => new List<String>{'Call with buyer'}
        };
        
        Test.setMock(HttpCalloutMock.class, new MockOpenAIRiskResponse());
        
        Test.startTest();
        DealPanelDTO.RiskExplanation result = DealPanelAI.explainRisk(opp.Id, contextPayload);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testExplainRisk_NullId() {
        Test.startTest();
        try {
            DealPanelAI.explainRisk(null, null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testExplainRisk_APIError() {
        setupOpenAISettings();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockOpenAIErrorResponse());
        
        Test.startTest();
        try {
            DealPanelAI.explainRisk(opp.Id, null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error') || e.getMessage().contains('Invalid'), 
                'Should contain error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testExplainRisk_RateLimitError() {
        setupOpenAISettings();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockOpenAIRateLimitResponse());
        
        Test.startTest();
        try {
            DealPanelAI.explainRisk(opp.Id, null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Rate limit') || e.getMessage().contains('Error'), 
                'Should contain rate limit error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDraftEmail_WithOpenAI() {
        setupOpenAISettings();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockOpenAIEmailResponse());
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.draftEmail(
            opp.Id, 
            'professional', 
            'follow-up', 
            null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.emailSubject, 'Subject should not be null');
        System.assertNotEquals(null, result.emailBody, 'Body should not be null');
        System.assert(result.emailSubject.contains('Follow'), 'Subject should mention follow-up');
    }
    
    @isTest
    static void testDraftEmail_FallbackToMock() {
        // Don't setup OpenAI settings - should fall back to mock
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.draftEmail(opp.Id, 'professional', 'follow-up', null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.emailSubject, 'Should have subject from mock');
    }
    
    @isTest
    static void testDraftEmail_NullId() {
        Test.startTest();
        try {
            DealPanelAI.draftEmail(null, 'professional', 'follow-up', null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDraftEmail_WithDifferentTones() {
        setupOpenAISettings();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockOpenAIEmailResponse());
        
        Test.startTest();
        // Test friendly tone
        DealPanelDTO.EmailDraft friendlyResult = DealPanelAI.draftEmail(opp.Id, 'friendly', 'check-in', null);
        // Test urgent tone
        DealPanelDTO.EmailDraft urgentResult = DealPanelAI.draftEmail(opp.Id, 'urgent', 'proposal', null);
        Test.stopTest();
        
        System.assertNotEquals(null, friendlyResult, 'Friendly result should not be null');
        System.assertNotEquals(null, urgentResult, 'Urgent result should not be null');
    }
    
    @isTest
    static void testGetMockRiskExplanation_AtRisk() {
        // Create opportunity with poor metrics
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;
        
        Opportunity riskyOpp = new Opportunity(
            Name = 'Risky Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
            // No NextStep set
        );
        insert riskyOpp;
        
        Test.startTest();
        DealPanelDTO.RiskExplanation result = DealPanelAI.getMockRiskExplanation(riskyOpp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.riskSummary.size() > 0, 'Should have risk summary items');
        System.assert(result.topNextSteps.size() > 0, 'Should have next steps');
        System.assert(result.questionsToAsk.size() > 0, 'Should have questions');
    }
    
    @isTest
    static void testGetMockRiskExplanation_Healthy() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Create completed task to improve metrics
        Task recentTask = new Task(
            WhatId = opp.Id,
            Subject = 'Recent Call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-2),
            Type = 'Call'
        );
        insert recentTask;
        
        // Add contact role
        Contact con = new Contact(FirstName = 'Test', LastName = 'User 2');
        insert con;
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Role = 'Influencer'
        );
        insert ocr;
        
        Test.startTest();
        DealPanelDTO.RiskExplanation result = DealPanelAI.getMockRiskExplanation(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetMockEmailDraft_FollowUp() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.getMockEmailDraft(opp.Id, 'professional', 'follow-up');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.emailSubject.contains('Follow'), 'Subject should mention follow-up');
        System.assert(result.emailBody.contains('Hello'), 'Professional tone should use Hello');
    }
    
    @isTest
    static void testGetMockEmailDraft_Friendly() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.getMockEmailDraft(opp.Id, 'friendly', 'check-in');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.emailSubject.contains('Check'), 'Subject should mention check-in');
        System.assert(result.emailBody.contains('Hi'), 'Friendly tone should use Hi');
    }
    
    @isTest
    static void testGetMockEmailDraft_Proposal() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.getMockEmailDraft(opp.Id, 'professional', 'proposal');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.emailSubject.contains('Proposal'), 'Subject should mention proposal');
    }
    
    @isTest
    static void testGetMockEmailDraft_NextSteps() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.getMockEmailDraft(opp.Id, null, 'next-steps');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.emailSubject.contains('Next Steps'), 'Subject should mention next steps');
    }
    
    @isTest
    static void testGetMockEmailDraft_DefaultValues() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DealPanelDTO.EmailDraft result = DealPanelAI.getMockEmailDraft(opp.Id, null, null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.emailSubject, 'Should have default subject');
        System.assertNotEquals(null, result.emailBody, 'Should have default body');
    }
}
