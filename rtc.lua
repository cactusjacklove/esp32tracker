-- Soft RTC.
-- Component config > Lua RTOS > General > Deep Sleep > * Maintain power for RTC IO
-- and under Component config > ESP32-specific >
-- make sure make sure "Timers used for gettimeofday function" option is set to
-- "RTC (and...) 
--

local function init()
   return rtc
end

local function setdt(secs)
   local dt=os.date("*t", secs)
   print("Setting RTC to ", os.date("%c", secs))
   cpu.settimeofday(secs)
end

local function getdt()
   return os.time()
end

local function sleep_until(tods)
   local now=os.time()
   local secs = tods - now
   print("Setting Alarm for ", os.date("%c", tods))
   print("So... Sleeping for ", secs, " seconds")
   cpu.sleep(secs)
end

local function close()
end

local function id()
   local rv=rv1805_hd
   rv:start()
   rv:address(i2caddr, false)
   rv:write(0x28)
   rv:start()
   rv:address(i2caddr, true)
   local v = rv:read()
   rv:stop()
   return v
end


return { init=init, id=id, sleep_until=sleep_until, time=getdt, set_time=setdt }
