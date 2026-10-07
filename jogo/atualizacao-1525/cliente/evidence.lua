-- Evidence schema v2. Result = completed check; state = latest observed connection.
-- Sequence/elapsedMs disambiguate callbacks occurring in the same UTC second.
local M = {}
local function utc() return os.date("!%Y-%m-%dT%H:%M:%SZ") end
function M.runId()
    local supplied = os.getenv("ENTREVEUS_RUN_ID")
    if supplied and supplied ~= "" then
        assert(supplied:match("^[%w_-]+$"), "Invalid evidence runId")
        return supplied
    end
    return "run-" .. os.date("!%Y%m%dT%H%M%SZ") .. "-" ..
        tostring(g_clock.millis()) .. "-" .. string.format("%08x", math.random(0, 0x7fffffff))
end

function M.new(options)
    local now = options.now or utc
    local tick = options.tick or function() return g_clock.millis() end
    local startTick = tick()
    local record = {data = {
        schemaVersion=2, runId=assert(options.runId), test=options.test,
        mode=options.mode, protocol=1525, startedAt=now(), isHistorical=false,
        success=false, formCredentialsMatch=false,
        result={status="running", scope=options.scope},
        state={connection="not_started", phase="starting"},
        events={}
    }}
    function record:save()
        self.data.updatedAt = now()
        if options.write then options.write(self.data) end
    end
    function record:refreshOrder()
        local successSequence, before, after = nil, 0, 0
        for _, event in ipairs(self.data.events) do
            if event.event == "checkCompleted" and event.passed then successSequence=event.sequence end
        end
        local count=0
        for _, event in ipairs(self.data.events) do
            if event.isError then
                count=count+1
                if successSequence and event.sequence < successSequence then before=before+1
                elseif successSequence then after=after+1 end
            end
        end
        local order="no_success_or_error_observed"
        if successSequence then
            order="no_error_observed"
            if before>0 and after>0 then order="errors_before_and_after_success"
            elseif before>0 then order="error_before_success"
            elseif after>0 then order="error_after_success" end
        elseif count>0 then order="error_without_verified_success" end
        self.data.eventSummary={
            errorOrder=order, errorCount=count, errorsBeforeSuccess=before,
            errorsAfterSuccess=after, successSequence=successSequence,
            orderBasis="sequence within this run; UTC timestamp plus elapsedMs",
            attemptInference="Order alone does not prove a separate login attempt."
        }
    end
    function record:event(name, fields)
        local event={event=name, timestamp=now(), runId=self.data.runId,
            sequence=#self.data.events+1, elapsedMs=math.max(0,tick()-startTick)}
        for key,value in pairs(fields or {}) do
            assert(event[key] == nil, "Cannot replace evidence identity")
            event[key]=value
        end
        self.data.events[#self.data.events+1]=event
        self.data.state.observedAt=event.timestamp
        self.data.state.lastEvent=name
        self:refreshOrder()
        self:save()
        return event
    end
    function record:error(name, message)
        self.data.state.connection="error"
        local event=self:event(name,{isError=true,message=tostring(message)})
        self.data.state.latestError={
            event=name, timestamp=event.timestamp, sequence=event.sequence,
            runId=event.runId, message=event.message
        }
        -- A later connection error must not silently rewrite a completed check.
        if self.data.result.status=="running" then
            self.data.result.status="failed"
            self.data.result.completedAt=event.timestamp
        end
        self:save()
    end
    function record:complete(passed, message)
        self.data.success=passed
        self.data.result.status=passed and "passed" or "failed"
        self.data.result.completedAt=now()
        self.data.result.reason=message
        self:event("checkCompleted",{passed=passed,reason=message})
    end
    return record
end

function M.fileRecorder(prefix, options)
    local runtime=os.getenv("LOCALAPPDATA"):gsub("\\","/") .. "/EntreVeus1525/"
    local fileName=prefix .. "-" .. options.runId .. ".json"
    local immutablePath=runtime .. fileName
    local existing=io.open(immutablePath,"rb")
    if existing then existing:close();error("Evidence run already exists") end
    -- Keep the previous legacy/mirror file byte for byte before replacing the mirror.
    local old=io.open(runtime .. prefix .. ".json","rb")
    if old then
        local bytes=old:read("*a");old:close()
        local backup=assert(io.open(runtime .. prefix .. "-before-" .. options.runId .. ".json","wb"))
        backup:write(bytes);backup:close()
    end
    options.write=function(data)
        local encoded=json.encode(data)
        for _,path in ipairs({immutablePath,runtime .. prefix .. ".json"}) do
            local out=assert(io.open(path,"w"))
            out:write(encoded);out:close()
        end
    end
    local recorder=M.new(options)
    recorder:event("runStarted")
    return recorder
end
return M

