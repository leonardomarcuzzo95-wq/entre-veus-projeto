-- Synthetic regression checks; no network, character or database operations.
return function(E)
    local outcomes={}
    local function fresh(id)
        return E.new({runId=id,test="synthetic-evidence-regression",mode="unit",
            scope="event ordering",now=function() return "2026-10-06T00:00:00Z" end,
            tick=function() return 10 end})
    end
    local a=fresh("unit-before")
    a:error("onLoginError","synthetic")
    a:event("onGameStart",{player="Synthetic QA"})
    a:complete(true)
    assert(a.data.eventSummary.errorOrder=="error_before_success")
    assert(a.data.success and a.data.error==nil and a.data.result.status=="passed")
    outcomes[#outcomes+1]="error_before_success"
    local b=fresh("unit-after")
    b:event("onGameStart");b:complete(true);b:error("onConnectionError","synthetic")
    assert(b.data.eventSummary.errorOrder=="error_after_success")
    assert(b.data.result.status=="passed" and b.data.state.connection=="error")
    outcomes[#outcomes+1]="completed_result_separate_from_connection_error"
    b:error("onLoginError","synthetic");b:complete(true);b:error("onConnectionError","synthetic")
    assert(b.data.eventSummary.errorOrder=="errors_before_and_after_success")
    outcomes[#outcomes+1]="errors_both_sides"
    local c=fresh("unit-failure")
    c:error("onLoginError","synthetic")
    assert(not c.data.success and c.data.result.status=="failed")
    assert(c.data.eventSummary.errorOrder=="error_without_verified_success")
    outcomes[#outcomes+1]="failure_without_verified_success"
    for _,record in ipairs({a,b,c}) do
        for sequence,event in ipairs(record.data.events) do
            assert(event.sequence==sequence and event.runId==record.data.runId)
            assert(event.timestamp=="2026-10-06T00:00:00Z")
        end
    end
    outcomes[#outcomes+1]="same_second_sequence_and_run_correlation"
    return {kind="synthetic-unit-tests",passed=true,checks=outcomes}
end

