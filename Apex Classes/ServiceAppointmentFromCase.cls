global class ServiceAppointmentFromCase {
    global class Input {
        @InvocableVariable(label='Case Number')
        public String caseNumbers;
    }

    global class Output {
        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Create Service Appointment')
    global static List<Output> createServiceAppointments(List<Input> inputList) {
        List<Output> responses = new List<Output>();
		String fieldInspection ='Field Inpection';
        Set<String> caseNumberSet = new Set<String>();
        for (Input input : inputList) {
            caseNumberSet.add(input.caseNumbers);
        }

        // Fetch Aadhaar details to get city
        Aadhaar_Document__c aadhaarDetail = [
            SELECT City__c 
            FROM Aadhaar_Document__c 
            WHERE Case__r.CaseNumber IN :caseNumberSet 
            LIMIT 1
        ];

        // Find matching service territory
        ServiceTerritory serviceTerritoryRecord = [
            SELECT Name, Id, City 
            FROM ServiceTerritory 
            WHERE City = :aadhaarDetail.City__c 
            LIMIT 1
        ];

        // Get the associated work order
        WorkOrder workOrder = [
            SELECT Id, ServiceTerritoryId, WorkTypeId, CaseId 
            FROM WorkOrder 
            WHERE Case.CaseNumber IN :CaseNumberSet 
            LIMIT 1
        ];
        workOrder.ServiceTerritoryId = serviceTerritoryRecord.Id;
        update workOrder;

        // Find the service resource in that territory
        ServiceTerritoryMember serviceMember = [
            SELECT Id, ServiceResource.Name, ServiceResourceId, ServiceTerritoryId 
            FROM ServiceTerritoryMember 
            WHERE ServiceTerritoryId = :serviceTerritoryRecord.Id 
            LIMIT 1
        ];
       
		WorkType workType = [SELECT Id, Name FROM WorkType WHERE Name = :fieldInspection];
        // Schedule for tomorrow at 11 AM
        DateTime startTime = DateTime.newInstance(System.today().addDays(1), Time.newInstance(11, 0, 0, 0));
        DateTime endTime = startTime.addHours(1);

        // Create the Service Appointment
        ServiceAppointment serviceAppoint = new ServiceAppointment();
        serviceAppoint.ServiceTerritoryId = serviceMember.ServiceTerritoryId;
        serviceAppoint.ParentRecordId = workOrder.Id;
        serviceAppoint.SchedStartTime = startTime;
        serviceAppoint.SchedEndTime = endTime;
        serviceAppoint.EarliestStartTime = startTime;
        serviceAppoint.DueDate = endTime;
        serviceAppoint.Duration = 60;
        serviceAppoint.WorkTypeId = workType.Id;
        serviceAppoint.Status = 'Scheduled';
        insert serviceAppoint;

        // Assign service resource
        AssignedResource assignedResourceRecord = new AssignedResource(
            ServiceAppointmentId = serviceAppoint.Id,
            ServiceResourceId = serviceMember.ServiceResourceId
        );
        insert assignedResourceRecord;

        // Build final user message
        Output out = new Output();
        out.message = 'Here we go!🚀 We have assigned one of our service resources, ' + 
                       serviceMember.ServiceResource.Name + 
                      ', who is located in the customer\'s territory, ' + 
                      serviceTerritoryRecord.City + 
                      '. ' +  serviceMember.ServiceResource.Name + 
                      ' will visit the customer tomorrow at 11 AM for in-person verification. ' +
                      'Would you like to send an email notification to acknowledge the customer about the in-person verification?';

        responses.add(out);
        return responses;
    }
}