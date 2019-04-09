local rx = pio.GPIO16
local tx = pio.GPIO17
local uartid = uart.UART1

local function init()
   uart.setpins(uartid,rx, tx)
   uart.attach(uartid, 9600, 8, uart.PARNONE, uart.STOP1)
   uart.lock(uartid)
end


local function send(str)
   print("#Sending<<"..str..">>")
   uart.write(uartid, str)
end

local function readline()
   return uart.read(uartid, "*el", 100)
end

local function expect(sndstr,secs,OK)
   local OK = OK or "OK"
   local maxsecs = secs or 2
   local end_ts = os.time() + maxsecs
   uart.consume(uartid)
   if sndstr and sndstr ~="" then send(sndstr) end
   local accum = ""
   while os.time() < end_ts do
      local resp = uart.read(uartid, "*l", maxsecs*1000)
      if resp then
	 print("#Got:", resp)
	 accum = accum .. "\n" .. resp
	 if accum:match(OK) or accum:match("ERROR") then
	    collectgarbage('collect')	
	    return accum
	 end
      end
   end
   collectgarbage('collect')	
   return accum
end

local function at(str)
   return expect("AT"..str.."\r")
end

function tryAT(cmd,times,secswait,resp)
   local times = times or 2
   local secs = secswait or 1
   local resp = resp or "OK"
   local res
   for i=1,times do
      res = expect("AT"..cmd.."\r",secs,resp)
      if res:match(resp) then break end
--      thread.sleep(secs)
   end
   return res
end

return {init=init, expect=expect, send=send, on=on, off=off,tryAT=tryAT, at=at}


