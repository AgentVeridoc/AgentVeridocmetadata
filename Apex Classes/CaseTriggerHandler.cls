public class CaseTriggerHandler {
    public static void checkEmailToCaseSubject(List<Case> newCases){
        List<Case> validCases = new List<Case>();
		for(Case caseRecord:newCases){ 
           String subjectLower = caseRecord.Subject != null ? caseRecord.Subject.toLowerCase() : '';
			Boolean isValid = subjectLower.contains('kyc') || 
                			  subjectLower.contains('aadhaar');
            if(isValid){
                validCases.add(caseRecord);   
                System.debug('valid Cases-->'+validCases);
    		}
            else{
                caseRecord.addError('Invalid Record');
            }
        }
    }
    
    public static void checkCaseHasAttachments(Map<Id, Case> newCases){
        //System.debug('Enqueuing Queueable job for Case IDs: ' + newCases.keySet());
		System.enqueueJob(new CaseAttachmentHandler(newCases.keySet()),1);
		//CaseAttachmentScheduler.scheduleJob(newCases.keySet());
	}
}