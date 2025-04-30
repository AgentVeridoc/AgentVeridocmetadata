public class CaseAttachmentHandler implements Queueable, Database.AllowsCallouts
{
    public set<Id> caseIds;
    public CaseAttachmentHandler(Set<Id> caseId) {
        this.caseIds = caseId;
        System.debug(this.caseIds);
    }
    public void execute(QueueableContext context){
       
        List<Case> caseList = [SELECT Id FROM Case WHERE Id IN :caseIds];
       for (Case caseRecord : caseList) {
            try {
                processCase(caseRecord.Id);
                
            } catch (Exception e) {
                System.debug('Error processing case: ' + caseRecord.Id + ' - ' + e.getMessage());
            }
        }
    }
    public void processCase(Id caseRecId){
       
        System.debug('caseRecord'+caseRecId);
        String parsedText;
        String name = '';
        String fatherName = '';
        String dob = '';
        String aadhaarNumber = '';
        String address = '';    
        Boolean isAddressBlock = false;
        Pattern aadhaarPattern = Pattern.compile('^\\d{12}$');
        String street = '';
        String city = '';
        String state = '';
        String zip = '';
		String acntName ='ICI BANK';
        Case caseRecord = [SELECT Id FROM Case WHERE Id =:caseRecId];
        Set<Id> emailMessageIds = new Set<Id>();
        String email ='';
        for(EmailMessage emailMessage: [SELECT Id, FromAddress FROM EmailMessage WHERE ParentId = :caseRecord.Id]){
            emailMessageIds.add(emailMessage.Id);   
            email = emailMessage.FromAddress;
        }
        
        Account accRecord = [SELECT Id FROM Account WHERE Name = :acntName LIMIT 1];
        Contact contact = new Contact();
        contact.Email = email;
        contact.AccountId = accRecord.Id;
        insert contact;
        
        caseRecord.ContactId = contact.Id;
		update caseRecord;
        Set<Id> contentDocumentIds = new Set<Id>();
        for(ContentDocumentLink contentDoc : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :emailMessageIds]){
            contentDocumentIds.add(contentDoc.ContentDocumentId);
        }

        List<String> versionData = new List<String>();
        for(ContentVersion content: [
            SELECT VersionData FROM ContentVersion 
            WHERE ContentDocumentId IN :contentDocumentIds AND FileType = 'PDF'
        ]){
            versionData.add(EncodingUtil.base64Encode(content.VersionData));
        }

        for(String base64File: versionData){
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.ocr.space/parse/image');  
            req.setMethod('POST');

            req.setHeader('apikey', 'K85376682288957');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String formattedBase64 = 'data:application/pdf;base64,' + base64File;
            String body = 'base64Image=' + EncodingUtil.urlEncode(formattedBase64, 'UTF-8') +
                          '&filetype=pdf&isOverlayRequired=true&OCREngine=2&scale=true';
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if(res.getStatusCode() == 200){
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> parsedResults = (List<Object>) jsonResponse.get('ParsedResults');
                Map<String, Object> firstResult = (Map<String, Object>) parsedResults[0];
                parsedText = (String) firstResult.get('ParsedText');
            } else {
                System.debug('OCR failed: ' + res.getStatus());
            }
        }

        System.debug('Parse Text --> ' + parsedText);

        if(parsedText != null){
            List<String> lines = parsedText.split('\n');

            for(Integer i = 0; i < lines.size(); i++){
                String line = lines[i].trim();

                if (String.isEmpty(name)){
                    Pattern namePattern = Pattern.compile('^[A-Za-z ]{5,}$');
                    Matcher nameMatcher = namePattern.matcher(line);
                    if (nameMatcher.matches() && !line.toLowerCase().contains('government')){
                        name = line;
                        continue;
                    }
                }

                if (String.isEmpty(dob) && line.toLowerCase().contains('dob')){
                    Pattern datePattern = Pattern.compile('(\\d{2}[\\/\\-]\\d{2}[\\/\\-]\\d{4})');
                    Matcher dateMatcher = datePattern.matcher(line);
                    if (dateMatcher.find()) {
                        dob = dateMatcher.group(1);
                    }
                    continue;
                }

                String numericLine = line.replaceAll('\\s', '');
                if (String.isEmpty(aadhaarNumber)) {
                    Matcher aadhaarMatcher = aadhaarPattern.matcher(numericLine);
                    if (aadhaarMatcher.matches()) {
                        String last4Digits = numericLine.right(4);
                        aadhaarNumber = '**** **** ' + last4Digits;
                        continue;
                    }
                }

                if (line.toLowerCase().startsWith('s/o')) {
                    isAddressBlock = true;
                    Pattern fatherPattern = Pattern.compile('(?i)S/O[:\\s]+([^,\\n]+)');
                    Matcher m = fatherPattern.matcher(line);
                    if (m.find()) {
                        fatherName = m.group(1).trim();
                    }

                    line = line.replaceFirst('S/O[:\\s]*' + fatherName, '').replaceFirst('^,\\s*', '');
                    if (!String.isBlank(line)) {
                        address += line + '\n';
                    }
                    continue;
                }

                if(line.toLowerCase().startsWith('address')) {
                    isAddressBlock = true;
                    if (!line.equalsIgnoreCase('Address:') && line != ''){
                        address += line + '\n';
                    }
                    continue;
                }

                if(isAddressBlock){
                    String digitsOnly = line.replaceAll('\\s', '');
                    Matcher aadhaarMatcher = aadhaarPattern.matcher(digitsOnly);

                    if(line == '' || aadhaarMatcher.matches() ||
                       line.toLowerCase().contains('vid') ||
                       line.toLowerCase().contains('uidai') ||
                       line.toLowerCase().contains('help@') ||
                       Pattern.matches('.*\\b19\\d{2}\\b', line)) {
                        isAddressBlock = false;
                        continue;
                    }

                    address += line + ', ';
                }
            }

            address = address.replaceAll(',\\s*,', ',');
            address = address.replaceAll(',\\s*$', '');
            address = address.trim();

            // 🌟 Smart Address Parsing
            List<String> addressLines = address.replace('\n', ',').split(',');
            List<String> cleanParts = new List<String>();
            for (String p : addressLines) {
                String trimmed = p.trim();
                if (!String.isBlank(trimmed)) {
                    cleanParts.add(trimmed);
                }
            }

            Integer stateZipIndex = -1;
            for (Integer i = cleanParts.size() - 1; i >= 0; i--) {
                if (Pattern.matches('.*\\-\\s*\\d{6}$', cleanParts[i])) {
                    stateZipIndex = i;
                    break;
                }
            }

            if (stateZipIndex != -1) {
                String stateZipLine = cleanParts[stateZipIndex];
                List<String> parts = stateZipLine.split('\\-');
                if (parts.size() == 2) {
                    state = parts[0].trim();
                    zip = parts[1].trim();
                }
                cleanParts.remove(stateZipIndex);
            }

            if (!cleanParts.isEmpty()) {
                city = cleanParts.remove(cleanParts.size() - 1);
            }

            street = String.join(cleanParts, ', ');

            // Debug final parsed info
            System.debug('Name ---> ' + name);
            System.debug('Father Name ---> ' + fatherName);
            System.debug('DOB ---> ' + dob);
            System.debug('Aadhaar ---> ' + aadhaarNumber);
            System.debug('Street ---> ' + street);
            System.debug('City ---> ' + city);
            System.debug('State ---> ' + state);
            System.debug('Zip Code ---> ' + zip);

            if(name != null || fatherName != null || dob != null || aadhaarNumber != null || 
               street != null || city != null || state != null || zip != null){
                Aadhaar_Document__c aadhaar = new Aadhaar_Document__c();
                aadhaar.Aadhaar_Number__c = aadhaarNumber;
                aadhaar.Name__c = name;
                aadhaar.DOB__c = dob;
                aadhaar.Street__c = street;
                aadhaar.City__c = city;
                aadhaar.State__c = state;
                aadhaar.Zip_Code__c = zip;
                aadhaar.Case__c = caseRecId;
                insert aadhaar;
            }
        }
     	    }    
}