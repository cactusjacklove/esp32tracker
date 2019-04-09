local mdm_hnd=require'mdm_esp32'
local rst = pio.GPIO26
local ri = pio.GPIO34
local pwrstat = ri
local pwr = pio.GPIO25
local dtr = pio.GPIO4
local wakepin = dtr

local function init_pins()
   pio.pin.setdir(pio.OUTPUT, pwr)
   pio.pin.sethigh(pwr)
   pio.pin.setdir(pio.OUTPUT, wakepin)
   pio.pin.sethigh(wakepin)
   pio.pin.setdir(pio.OUTPUT, rst)
   pio.pin.sethigh(rst)
   pio.pin.setdir(pio.INPUT, ri)
   pio.pin.setpull(pio.PULLDOWN, ri)
end

local function is_on()
   return pio.pin.getval(pwrstat) == 1
end

local function powercycle()
   print"Power cycling..."
   pio.pin.setlow(pwr)
   thread.sleepms(1500)
   pio.pin.sethigh(pwr)
end

local function off()
   if  is_on() then
      powercycle()
   end
end

local function on()
   if not is_on() then
      powercycle()
   end
   pio.pin.setlow(rst)
   thread.sleepms(25)
   pio.pin.sethigh(rst)
   thread.sleep(5)
end

local cellradio_is_on = false
local function cellradio_on()
   if cellradio_is_on then return end
   local res = mdm_hnd.tryAT("+CFUN=1",2,1)
   thread.sleep(2)		-- wait
   for i,v in pairs{'E1', 'V1', '+CMEE=2', '+CMGF=1' } do
      res = mdm_hnd.tryAT(v,5,1)
   end
--   res = mdm_hnd.tryAT("",5,1,"Ready")
   cellradio_is_on = true
--   thread.sleep(2)		-- wait
end

local function cellradio_off()
   cellradio_is_on = false
   local res = mdm_hnd.tryAT("+CFUN=0",5,1)
end

local function sleep()
   pio.pin.sethigh(wakepin)
   cellradio_off()
   res = mdm_hnd.tryAT("+CSCLK=1",5,1)
end

local function wake()
   pio.pin.setlow(wakepin)
--   thread.sleepms(100)
--   pio.pin.sethigh(wakepin)
   thread.sleepms(100)
   local res = mdm_hnd.tryAT("+CSCLK=0",3,1)
   if res:match("ERROR") then
      on()
   end
   cellradio_off()
end

local function battery()
   local bats = mdm_hnd.tryAT("+CBC")
   local percent,mv = bats:match('%s++CBC:%s+%d+,(%d+),(%d+)')
   mv = mv or "Unknown voltage"
   return mv
end

local function new_imei(imei)
   mdm_hnd.tryAT('+ceng=1')
   mdm_hnd.tryAT('+ egmr=1,7,"'..imei..'"')
   mdm_hnd.tryAT('+ceng=0')
end

local function send_msg(phones,str)
   cellradio_on()
   for _,phone in ipairs(phones) do
      local res = mdm_hnd.tryAT('+CMGS="'..phone..'"',2,30,">")
      if res:match(">") then 
	 thread.sleep(1)
	 mdm_hnd.send(str)
	 mdm_hnd.expect("\026",60)
      end
      mdm_hnd.expect("\rAT\r",5)
   end
   cellradio_off()
end


local function delete_msg(msgnum)
   print("#Deleting.."..msgnum)
   return mdm_hnd.expect("AT+CMGD="..msgnum.."\r")
end

local function get_msg(msgnum)
   cellradio_on()
   local msg = mdm_hnd.expect("AT+CMGR="..msgnum.."\r")
   local mstat,from,body =
      msg:match('.+CMGR.+ "([^"]+)","([^"]+)","[^"]*","[^"]*"\n(.+)\nOK')
   if not mstat then
      return nil,nil
   end
   return from,body
end

local function init()
   init_pins()
   mdm_hnd.init()
--   on()
--   cellradio_off()
end


return { on=on, off=off, is_on=is_on, init=init, get_msg=get_msg,
	 battery=battery,  sleep=sleep, wake=wake,
	 send=send_msg, delete_msg=delete_msg }

