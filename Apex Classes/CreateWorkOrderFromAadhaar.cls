global with sharing class CreateWorkOrderFromAadhaar {

    global class Input {
        @InvocableVariable(label='Case Number')
        public String caseNumbers;
    }

    global class Output {
        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Create Work Order from Aadhaar')
    global static List<Output> createWorkOrders(List<Input> inputList) {
        List<Output> responses = new List<Output>();
  		List<WorkOrder> workOrders = new List<WorkOrder>();
      	Set<String> caseNumberSet = new Set<String>();
        
        for (Input input : inputList) {
            caseNumberSet.add(input.caseNumbers);
        }

        // Fetch KYC and Aadhaar details
        List<Aadhaar_Document__c> aadhaarDocuments = [SELECT Id, Name__c, Street__c, City__c, State__c, Zip_Code__c,Case__c, Case__r.AccountId FROM Aadhaar_Document__c
            WHERE Case__r.CaseNumber IN :caseNumberSet
        ];
		
        for (Aadhaar_Document__c aadhaarDocument : aadhaarDocuments){
         	 WorkOrder workOrder = new WorkOrder(
                 Subject = 'Aadhaar In-Person Verification',
                 Status = 'New',
                 CaseId = aadhaarDocument.Case__c,
                 City = aadhaarDocument.City__c,
                 Street = aadhaarDocument.Street__c,
                 State = aadhaarDocument.State__c,
                 PostalCode = aadhaarDocument.Zip_Code__c,
                 AccountId = aadhaarDocument.Case__r.AccountId,
                 Description = 'Auto-created from Aadhaar details via Agentforce'
             );
            workOrders.add(workOrder);
        }
        
        if(!workOrders.isEmpty()){
            insert WorkOrders;
            Output out = new Output();
         	responses.add(out);
        }
        else{
        	Output out = new Output();
            out.message = 'No Aadhaar details found for the provided CaseNumber';
            responses.add(out);
        }
        
        return responses;
    }
}