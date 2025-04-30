trigger CaseTrigger on Case (before insert, after insert) {
    if(Trigger.isBefore && Trigger.isInsert){
        CaseTriggerHandler.checkEmailToCaseSubject(Trigger.New);
    }
    if(Trigger.isAfter && Trigger.isInsert){
      CaseTriggerHandler.checkCaseHasAttachments(Trigger.NewMap);
    }

}