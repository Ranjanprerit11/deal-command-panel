/**
 * @description AI integration service for the Deal Command Panel
 * Provides risk explanation and email drafting via OpenAI API
 */
public with sharing class DealPanelAI {
    
    private static final Integer TIMEOUT_MS = 60000; // 60 seconds for AI responses
    
    /**
     * @description Get OpenAI settings from Custom Setting
     */
    private static OpenAI_Settings__c getSettings() {
        OpenAI_Settings__c settings = OpenAI_Settings__c.getInstance();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            return null;
        }
        return settings;
    }
    
    /**
     * @description Check if OpenAI is configured
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isOpenAIConfigured() {
        return getSettings() != null;
    }
    
    /**
     * @description Get AI-generated risk explanation and next steps
     * @param opportunityId The opportunity record ID
     * @param contextPayload Context data for AI analysis (non-sensitive)
     * @return RiskExplanation containing risk summary, next steps, and questions
     */
    @AuraEnabled
    public static DealPanelDTO.RiskExplanation explainRisk(Id opportunityId, Map<String, Object> contextPayload) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required');
        }
        
        OpenAI_Settings__c settings = getSettings();
        if (settings == null) {
            // Fall back to mock if not configured
            return getMockRiskExplanation(opportunityId);
        }
        
        // Build context if not provided
        DealPanelDTO.AIContext context;
        if (contextPayload == null || contextPayload.isEmpty()) {
            context = DealPanelService.buildAIContext(opportunityId);
        } else {
            context = (DealPanelDTO.AIContext) JSON.deserialize(
                JSON.serialize(contextPayload), 
                DealPanelDTO.AIContext.class
            );
        }
        
        // Build the prompt
        String systemPrompt = buildRiskSystemPrompt();
        String userPrompt = buildRiskUserPrompt(context);
        
        try {
            String responseContent = callOpenAI(settings, systemPrompt, userPrompt);
            return parseRiskResponse(responseContent);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OpenAI API Error: ' + e.getMessage());
            throw new AuraHandledException('Error getting AI analysis: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get AI-generated follow-up email draft
     * @param opportunityId The opportunity record ID
     * @param tone Email tone (professional, friendly, urgent)
     * @param goal Email goal (follow-up, check-in, proposal, etc.)
     * @param contextPayload Context data for AI (non-sensitive)
     * @return EmailDraft containing subject and body
     */
    @AuraEnabled
    public static DealPanelDTO.EmailDraft draftEmail(
        Id opportunityId, 
        String tone, 
        String goal, 
        Map<String, Object> contextPayload
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required');
        }
        
        OpenAI_Settings__c settings = getSettings();
        if (settings == null) {
            // Fall back to mock if not configured
            return getMockEmailDraft(opportunityId, tone, goal);
        }
        
        // Build context if not provided
        DealPanelDTO.AIContext context;
        if (contextPayload == null || contextPayload.isEmpty()) {
            context = DealPanelService.buildAIContext(opportunityId);
        } else {
            context = (DealPanelDTO.AIContext) JSON.deserialize(
                JSON.serialize(contextPayload), 
                DealPanelDTO.AIContext.class
            );
        }
        
        String toneStyle = String.isNotBlank(tone) ? tone : 'professional';
        String emailGoal = String.isNotBlank(goal) ? goal : 'follow-up';
        
        // Build the prompt
        String systemPrompt = buildEmailSystemPrompt();
        String userPrompt = buildEmailUserPrompt(context, toneStyle, emailGoal);
        
        try {
            String responseContent = callOpenAI(settings, systemPrompt, userPrompt);
            return parseEmailResponse(responseContent);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OpenAI API Error: ' + e.getMessage());
            throw new AuraHandledException('Error generating email draft: ' + e.getMessage());
        }
    }
    
    /**
     * @description Build system prompt for risk analysis
     */
    private static String buildRiskSystemPrompt() {
        return 'You are a sales coach AI assistant helping sales reps analyze deal health and identify risks. ' +
               'You provide actionable, specific advice based on deal metrics. ' +
               'Always respond in valid JSON format with the following structure:\n' +
               '{\n' +
               '  "riskSummary": ["string array of 2-4 key risk observations"],\n' +
               '  "topNextSteps": ["string array of 2-4 specific actionable next steps"],\n' +
               '  "questionsToAsk": ["string array of 2-3 discovery questions for the customer"]\n' +
               '}\n' +
               'Be concise but specific. Each item should be one clear sentence.';
    }
    
    /**
     * @description Build user prompt for risk analysis with context
     */
    private static String buildRiskUserPrompt(DealPanelDTO.AIContext context) {
        String prompt = 'Analyze this sales opportunity and provide risk assessment:\n\n';
        prompt += 'Deal Health Score: ' + context.healthScore + '/100 (' + context.healthLabel + ')\n';
        prompt += 'Current Stage: ' + context.stageName + '\n';
        prompt += 'Days in Current Stage: ' + context.stageAgeDays + '\n';
        prompt += 'Days Since Last Activity: ' + context.activityGapDays + '\n';
        prompt += 'Close Date Push Count: ' + context.closeDatePushCount + '\n';
        prompt += 'Number of Stakeholders: ' + context.contactRoleCount + '\n';
        prompt += 'Has Defined Next Step: ' + context.hasNextStep + '\n';
        
        if (context.recentActivitySubjects != null && !context.recentActivitySubjects.isEmpty()) {
            prompt += 'Recent Activities: ' + String.join(context.recentActivitySubjects, ', ') + '\n';
        }
        
        prompt += '\nProvide your analysis in the JSON format specified.';
        return prompt;
    }
    
    /**
     * @description Build system prompt for email drafting
     */
    private static String buildEmailSystemPrompt() {
        return 'You are a sales email assistant that drafts professional sales follow-up emails. ' +
               'Create emails that are concise, personalized based on deal context, and have clear calls to action. ' +
               'Always respond in valid JSON format with the following structure:\n' +
               '{\n' +
               '  "emailSubject": "string - a compelling subject line",\n' +
               '  "emailBody": "string - the full email body with proper formatting"\n' +
               '}\n' +
               'Use \\n for line breaks in the email body. Do not include placeholder names - use generic greetings.';
    }
    
    /**
     * @description Build user prompt for email drafting with context
     */
    private static String buildEmailUserPrompt(DealPanelDTO.AIContext context, String tone, String goal) {
        String prompt = 'Draft a ' + tone + ' ' + goal + ' email for this sales opportunity:\n\n';
        prompt += 'Current Stage: ' + context.stageName + '\n';
        prompt += 'Days Since Last Contact: ' + context.activityGapDays + '\n';
        prompt += 'Deal Health: ' + context.healthLabel + ' (' + context.healthScore + '/100)\n';
        prompt += 'Has Defined Next Step: ' + context.hasNextStep + '\n';
        
        if (context.recentActivitySubjects != null && !context.recentActivitySubjects.isEmpty()) {
            prompt += 'Recent Activities: ' + String.join(context.recentActivitySubjects, ', ') + '\n';
        }
        
        prompt += '\nTone: ' + tone + '\n';
        prompt += 'Goal: ' + goal + '\n';
        prompt += '\nProvide the email in the JSON format specified.';
        return prompt;
    }
    
    /**
     * @description Make HTTP callout to OpenAI API
     */
    private static String callOpenAI(OpenAI_Settings__c settings, String systemPrompt, String userPrompt) {
        String endpoint = String.isNotBlank(settings.Endpoint__c) 
            ? settings.Endpoint__c 
            : 'https://api.openai.com/v1/chat/completions';
        String model = String.isNotBlank(settings.Model__c) 
            ? settings.Model__c 
            : 'gpt-4o-mini';
        
        // Build request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => model,
            'messages' => new List<Map<String, String>>{
                new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String, String>{ 'role' => 'user', 'content' => userPrompt }
            }
        };
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
        req.setTimeout(TIMEOUT_MS);
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String errorMessage = 'OpenAI API error: ' + res.getStatusCode();
            if (errorResponse.containsKey('error')) {
                Map<String, Object> error = (Map<String, Object>) errorResponse.get('error');
                if (error.containsKey('message')) {
                    errorMessage = String.valueOf(error.get('message'));
                }
            }
            throw new CalloutException(errorMessage);
        }
        
        // Parse OpenAI response
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> choices = (List<Object>) responseBody.get('choices');
        if (choices == null || choices.isEmpty()) {
            throw new CalloutException('No response from OpenAI');
        }
        
        Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
        Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
        Object contentObj = message.get('content');
        
        if (contentObj == null) {
            throw new CalloutException('OpenAI returned empty content');
        }
        
        String content = String.valueOf(contentObj);
        if (String.isBlank(content)) {
            throw new CalloutException('OpenAI returned blank content');
        }
        
        // Clean up the response - remove markdown code blocks if present
        content = content.trim();
        if (content.startsWith('```json')) {
            content = content.substringAfter('```json').substringBeforeLast('```').trim();
        } else if (content.startsWith('```')) {
            content = content.substringAfter('```').substringBeforeLast('```').trim();
        }
        
        return content;
    }
    
    /**
     * @description Parse risk explanation response from OpenAI
     */
    private static DealPanelDTO.RiskExplanation parseRiskResponse(String responseContent) {
        DealPanelDTO.RiskExplanation result = new DealPanelDTO.RiskExplanation();
        
        if (String.isBlank(responseContent)) {
            throw new JSONException('Empty response from AI');
        }
        
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseContent);
            
            // Parse risk summary
            if (response.containsKey('riskSummary')) {
                Object riskData = response.get('riskSummary');
                if (riskData instanceof List<Object>) {
                    for (Object item : (List<Object>) riskData) {
                        result.riskSummary.add(String.valueOf(item));
                    }
                }
            }
            
            // Parse top next steps
            if (response.containsKey('topNextSteps')) {
                Object stepsData = response.get('topNextSteps');
                if (stepsData instanceof List<Object>) {
                    for (Object item : (List<Object>) stepsData) {
                        result.topNextSteps.add(String.valueOf(item));
                    }
                }
            }
            
            // Parse questions to ask
            if (response.containsKey('questionsToAsk')) {
                Object questionsData = response.get('questionsToAsk');
                if (questionsData instanceof List<Object>) {
                    for (Object item : (List<Object>) questionsData) {
                        result.questionsToAsk.add(String.valueOf(item));
                    }
                }
            }
        } catch (Exception e) {
            throw new JSONException('Failed to parse AI response: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Parse email draft response from OpenAI
     */
    private static DealPanelDTO.EmailDraft parseEmailResponse(String responseContent) {
        DealPanelDTO.EmailDraft result = new DealPanelDTO.EmailDraft();
        
        if (String.isBlank(responseContent)) {
            throw new JSONException('Empty response from AI');
        }
        
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseContent);
            
            if (response.containsKey('emailSubject')) {
                result.emailSubject = String.valueOf(response.get('emailSubject'));
            } else {
                result.emailSubject = 'Follow-up';
            }
            
            if (response.containsKey('emailBody')) {
                result.emailBody = String.valueOf(response.get('emailBody'));
            } else {
                result.emailBody = 'Unable to generate email body. Please try again.';
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to parse email response: ' + responseContent);
            throw new JSONException('Failed to parse AI email response: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Generate mock risk explanation for testing/demo purposes
     * Used when OpenAI is not configured
     */
    @AuraEnabled
    public static DealPanelDTO.RiskExplanation getMockRiskExplanation(Id opportunityId) {
        DealPanelDTO.AIContext context = DealPanelService.buildAIContext(opportunityId);
        DealPanelDTO.RiskExplanation result = new DealPanelDTO.RiskExplanation();
        
        // Generate contextual risk summary
        if (context.healthLabel == 'At Risk') {
            result.riskSummary.add('This deal shows multiple warning signs that require immediate attention.');
        } else if (context.healthLabel == 'Watch') {
            result.riskSummary.add('This deal has some areas that need monitoring.');
        } else {
            result.riskSummary.add('This deal is progressing well with good engagement.');
        }
        
        if (context.activityGapDays != null && context.activityGapDays > 14) {
            result.riskSummary.add('No recent customer touchpoints detected (' + context.activityGapDays + ' days gap).');
        }
        
        if (context.stageAgeDays != null && context.stageAgeDays > 30) {
            result.riskSummary.add('Deal has been in ' + context.stageName + ' stage for ' + context.stageAgeDays + ' days.');
        }
        
        if (context.closeDatePushCount != null && context.closeDatePushCount >= 2) {
            result.riskSummary.add('Close date has been pushed ' + context.closeDatePushCount + ' times, indicating timeline uncertainty.');
        }
        
        if (context.contactRoleCount < 2) {
            result.riskSummary.add('Limited stakeholder engagement with only ' + context.contactRoleCount + ' contact(s) identified.');
        }
        
        // Generate next steps
        if (context.activityGapDays != null && context.activityGapDays > 7) {
            result.topNextSteps.add('Schedule a check-in call with the primary contact.');
        }
        
        if (!context.hasNextStep) {
            result.topNextSteps.add('Define and document the next concrete step for this opportunity.');
        }
        
        if (context.contactRoleCount < 2) {
            result.topNextSteps.add('Identify and engage additional stakeholders in the decision process.');
        }
        
        result.topNextSteps.add('Review competitive landscape and ensure value proposition is clear.');
        
        // Generate questions to ask
        result.questionsToAsk.add('What is the timeline for making a final decision?');
        result.questionsToAsk.add('Who else needs to be involved in the evaluation process?');
        result.questionsToAsk.add('Are there any concerns or objections we haven\'t addressed?');
        
        return result;
    }
    
    /**
     * @description Generate mock email draft for testing/demo purposes
     * Used when OpenAI is not configured
     */
    @AuraEnabled
    public static DealPanelDTO.EmailDraft getMockEmailDraft(Id opportunityId, String tone, String goal) {
        DealPanelDTO.AIContext context = DealPanelService.buildAIContext(opportunityId);
        DealPanelDTO.EmailDraft result = new DealPanelDTO.EmailDraft();
        
        String toneStyle = String.isNotBlank(tone) ? tone : 'professional';
        String emailGoal = String.isNotBlank(goal) ? goal : 'follow-up';
        
        // Generate subject based on goal
        if (emailGoal == 'follow-up') {
            result.emailSubject = 'Following Up on Our Conversation';
        } else if (emailGoal == 'check-in') {
            result.emailSubject = 'Quick Check-In';
        } else if (emailGoal == 'proposal') {
            result.emailSubject = 'Your Customized Proposal';
        } else if (emailGoal == 'next-steps') {
            result.emailSubject = 'Next Steps for Our Partnership';
        } else {
            result.emailSubject = 'Following Up';
        }
        
        // Generate body based on tone and context
        String greeting = toneStyle == 'friendly' ? 'Hi' : 'Hello';
        String closing = toneStyle == 'friendly' ? 'Best' : 'Best regards';
        
        result.emailBody = greeting + ',\n\n';
        
        if (emailGoal == 'follow-up') {
            result.emailBody += 'I wanted to follow up on our recent conversation and see if you had any questions about what we discussed.\n\n';
            
            if (context.activityGapDays != null && context.activityGapDays > 14) {
                result.emailBody += 'It\'s been a little while since we last connected, and I wanted to make sure you have everything you need to move forward.\n\n';
            }
        } else if (emailGoal == 'check-in') {
            result.emailBody += 'I wanted to check in and see how things are progressing on your end.\n\n';
        }
        
        result.emailBody += 'Please let me know if you have any questions or if there\'s anything I can help with.\n\n';
        result.emailBody += closing + ',\n[Your Name]';
        
        return result;
    }
}
