global with sharing class SendEmailForVerfication {

    global class Input{
        @InvocableVariable(label='Case Number')
        public String caseNumbers;
    }

    global class Output{
        @InvocableVariable
        public String message; // if you want to return any success/failure message, optional
    }

    @InvocableMethod(label='Send Email Notification for In-Person Verification')
    global static List<Output> sendEmailToCaseCreator(List<Input> inputList) {
        List<Output> responses = new List<Output>();

        Set<String> caseNumberSet = new Set<String>();
        for (Input input : inputList) {
            caseNumberSet.add(input.caseNumbers);
        }

        List<Case> cases = [
            SELECT Id, Contact.Email, Contact.FirstName, Contact.LastName, Contact.Account.Name, CaseNumber
            FROM Case
            WHERE CaseNumber IN :caseNumberSet
        ];

        for (Case caseRecord : cases) {
            if (caseRecord.Contact != null && caseRecord.Contact.Email != null) {
                String email = caseRecord.Contact.Email;
                String accountName = caseRecord.Contact.Account != null ? caseRecord.Contact.Account.Name : 'ICI Bank';

                // Email Subject and Body
                String subject = 'ICI Bank - Loan Application: In-Person Verification Scheduled';
                String body = 'Dear ' + caseRecord.Contact.FirstName + ' ' + caseRecord.Contact.LastName + ',\n\n' +
                              'We have verified your Aadhaar details and scheduled an in-person verification. One of our service representatives will visit you tomorrow morning 11 AM for the verification. Please ensure your availability.\n\n' +
                              'Thank you for choosing ' + accountName + '.\n\n' +
                              'Best Regards,\n' + accountName;

                sendEmail(email, subject, body);
            } else {
                System.debug('No contact email found for Case: ' + caseRecord.Id);
            }

            Output out = new Output();
			out.message = 'Awesome! The email has been sent to customer successfully. You are doing great🎉. Please let me know if you need any further assistance!';

            responses.add(out);
        }

        return responses;
    }

    private static void sendEmail(String toEmail, String subject, String body) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {toEmail});
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}