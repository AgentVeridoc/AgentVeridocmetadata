public class ShowAadhaarDocuments
{
	@invocableMethod
    public static list<String> showAadhaarDocuments(List<String> caseNumbers){
        List<String> response = new List<String>();
 		List<case> cases= [SELECT Id, caseNumber, (SELECT Aadhaar_Number__c, Name__c, DOB__c, Street__c,
                                    State__c, City__c, Zip_Code__c, Case__c FROM Aadhaar_Documents__r) from Case WHERE caseNumber IN :caseNumbers];
        if(!cases.isEmpty()){
            for(Case caseRecord: cases){
                if(!caseRecord.Aadhaar_Documents__r.isEmpty()){
                    
                    Aadhaar_Document__c aadhaarDoc = caseRecord.Aadhaar_Documents__r[0];
              		String aadhaar = String.valueOf(aadhaarDoc.Aadhaar_Number__c).replaceAll('\\s+', '');
                    String maskedAadhaar = '**** **** '+ aadhaar.substring(8,12);
                    response.add('Aadhaar Number: ' +maskedAadhaar +
                                + '\n' + 'Name: '+ aadhaarDoc.Name__c
                                + '\n' + 'DOB: '+ aadhaarDoc.DOB__c
                                + '\n' + 'Street: '+ aadhaarDoc.Street__c 
                                + '\n' + 'City: '+ aadhaarDoc.City__c 
                                + '\n' + 'Zip Code: '+ aadhaarDoc.Zip_Code__c + '\n\n'
								+'Would you like to initiate in-person verification for this customer?');
				}
            }
        }
        System.debug(response);
    	return response;
    }
}