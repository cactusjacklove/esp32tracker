print "===== Version 1.4 ======"
dofile'config.dat'

mdm = require'sim808_gsm'
gps = require'sim808_gps'
gf = require'fence'
accel = require'lis3dh'
rtc=require'rtc'

rtc.init()
local now = rtc.time()

print "****Press Enter to Interrupt..***"
if uart.read(uart.UART0, "*l", 3000) then
   assert(false)
end

mdm.init()
accel.init()

function geo_url(fix)
   return "https://maps.google.com/maps?q="..fix.coords[1].."+"..fix.coords[2]
end

local fencetrtcram = 0x50001E00
local parkedrtcram = 0x50001FE9
local beaconrtcram = 0x50001FF0
local checkrtcram =  0x50001FF4
local function rtcramval(addr,v)
   if v then
      ulp.valueat(addr, v & 0xFFFF)
      ulp.valueat(addr+2, v>>16 & 0xFFFF)
   end
   return ulp.valueat(addr+2) << 16 | ulp.valueat(addr)
end
function ulp_beaconts(v) return rtcramval(beaconrtcram,v) end
function ulp_checkts(v) return rtcramval(checkrtcram,v) end
function ulp_timetoparkts(v) return rtcramval(parkedrtcram,v) end

function set_current_fence(idx)
   print("**********Setting fence to ", idx)
   ulp.valueat(fencetrtcram,idx)
end

function current_fence()
   return tonumber(ulp.valueat(fencetrtcram))
end


-- See if this is a reset that does NOT retain RTC values.
if cpu.resetreason() == 16 then
   print"Reset!!"
   ulp_beaconts(now)
   ulp_checkts(now)
   ulp_timetoparkts(now+math.floor(Park.whenidle*60))
   set_current_fence(0)
end

local beaconts = ulp_beaconts()
local checkts = ulp_checkts()

function approx(s1, s2)
   return math.abs(s1-s2) < (20)
end

function fencecross(out,into)
   local intonm = (Fences[into] and Fences[into].name) and Fences[into].name or
      tostring(into)
   local outnm = (Fences[out] and Fences[out].name) and Fences[out].name or
      tostring(out)
   local outstr = out == 0 and "" or "([Leaving] Fence "..outnm..")"
   local instr = into == 0 and "" or "[Entering] Fence "..intonm
   return outstr.." "..instr
end

function infence(fidx)
   local name = (Fences[fidx] and Fences[fidx].name) and Fences[fidx].name or
      tostring(fidx)
   return fidx > 0 and "In Fence "..name or "No Fence"
end

local radiosilence = true
local parked
local ismoving = accel.is_moving()

local function motionstat()
   return (parked and "[Parked] " or (ismoving and "[Moving] " or "[Moving?] "))
end

-- print("Now =", now, "Beacon_ts =", beaconts, "Check_ts=", checkts)
local isbeacontime = approx(beaconts,now) and true or false
local ischecktime = approx(checkts,now) and true or false

print("beacon time?", isbeacontime, "GPS/Fence check time?", ischecktime)
print("Parked?", parked, ulp_timetoparkts(), "Current Fence", current_fence())

local cfidx = current_fence() or 0

local maxfixsecs = math.floor(GPS.maxfixtime * 60)
local maxfixduration = os.time() + maxfixsecs
local fix = nil

mdm.on()
gps.on()

-- If we are going to park, then beacon once
if now > ulp_timetoparkts() then
   if not parked then
      print"Entering Park..."
      isbeacontime = true
      parked = true
   end
else
   parked = false
end

if ismoving then
   print"Moving...."
   ulp_timetoparkts(now+math.floor(Park.whenidle*60))
   if parked then
      print"Leaving Park..."
      parked = false
      isbeacontime = true	-- force a beacon
   end
end

gps.start()
while  os.time() < maxfixduration do
   currentts = rtc.time()
   repeat
      fix = gps.fix()
   until (fix and fix.sats >= GPS.minsats) or os.time() >= maxfixduration
   if fix then print("Sats=", fix.sats) end
   if fix then
      collectgarbage('collect')
      local fence_idx
      fence_idx, radiosilence,_ = gf.check_fences(Fences, fix.coords)
      print("Fence = ", fence_idx, "Radio silence =", radiosilence)
      local nows = os.date(Beacon.useGPStime and "%H:%M:%S" or "%c",fix.utc)
      gps.stop()
      if  cfidx ~= fence_idx then
	 if  not radiosilence then
	    mdm.send(Modem.destphones,nows.." ("..mdm.battery()..
			"mv)"..fencecross(cfidx,fence_idx)..": "..geo_url(fix))
	 end
	 set_current_fence(fence_idx)
	 cfidx = fence_idx
	 break
      end
      if not radiosilence and isbeacontime then
	 mdm.send(Modem.destphones,nows.." ("..mdm.battery().."mv) "..
		     motionstat()..
		     infence(fence_idx)..": "..geo_url(fix))
      end
      break
   end
   collectgarbage('collect')
end
collectgarbage('collect')
gps.stop()
gps.off()
print("Fence=",infence(cfidx), "Radio Silence?=", radiosilence, "beacon time?=",
      isbeacontime, "Parked=", parked)
if not fix and not radiosilence and isbeacontime then
   local nows = os.date(Beacon.useGPStime and "%H:%M:%S" or "%c",rtc.time())
   mdm.send(Modem.destphones,nows.." ("..mdm.battery().."mv) "..
	       motionstat().." No fix.")
end


if not parked then
   mdm.sleep()
else
   print"Parked.. turning modem off."
   mdm.off()
end

local checkrate = (cfidx > 0 and  Fences[cfidx] and Fences[cfidx].checkrate) and
   Fences[cfidx].checkrate or GPS.defaultcheckrate

local beaconrate = parked and Park.beaconrate or ((cfidx > 0 and  Fences[cfidx] and Fences[cfidx].beaconrate) and  Fences[cfidx].beaconrate or Beacon.defaultrate)

if isbeacontime or beaconts < now then
   -- Use the now set when we woke up.
   beaconts = now + math.floor((beaconrate*60))
   ulp_beaconts(beaconts)
end

if ischecktime or checkts < now then
   -- from *now*, not when we work up
   checkts = rtc.time() + math.floor(checkrate*60)
   ulp_checkts(checkts)

end

local sleepsecs

if parked then
   sleepsecs = beaconts - rtc.time() -- no checks when parked
else
   sleepsecs = math.min(beaconts,checkts) - rtc.time()
end
print("Sleeping for", sleepsecs, "seconds")

if sleepsecs < 0 then
   sleepsecs = 2
end

-- warning: Maximum of 35 minutes (2^31 microseconds)
-- we will need to deal with this for long parks (with no periodic beacons)
-- essentially not sleeping time based... or just waking up early in 35 minute
-- increments.
cpu.wakeupon(cpu.WAKEUP_TIMER, math.min(2^31, sleepsecs*1000000))
if parked then
   cpu.wakeupon(cpu.WAKEUP_EXT0, accel.int1pin, 1)
end
cpu.deepsleep()

