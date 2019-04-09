local mdm_hnd=require'mdm_esp32'
local function init()
   mdm_hnd.tryAT("+CGPSPWR=1",2,2)		-- some sim808 chips want this
end

local function start()
   mdm_hnd.tryAT("+CGPSOUT=2",2,2)
end

local function DMm_Dd(dmm, pos)
   local sign = pos and 1 or -1
   local D = math.floor(dmm/100)
   local M = (dmm-(D*100))/60
   return sign * (D+M)
end

local function parse_GPGGA(str)
   local utc,lat_s,ns,lon_s,ew,fix,sats =
      str:match'.+GGA,([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),(%d),([^,]+)'
   if fix ~= '1' then return nil end
   -- convert the lat/lon stuff to soemthing useful..
   -- D.M.m -> D.d 
   local lat = DMm_Dd(tonumber(lat_s), ns == 'N')
   local lon = DMm_Dd(tonumber(lon_s), ns == 'E')
   local now = os.date'*t'
   local hr,min,sec = utc:match'(%d%d)(%d%d)(%d%d)'
   return { sats=tonumber(sats), coords = {lat,lon}, utc=
	       os.time{year=now.year, month=now.month, day=now.day,
		       hour=tonumber(hr), min=tonumber(min), sec=tonumber(sec)}}
end

local function fix()
   local res = mdm_hnd.expect("",2,"GPGGA")
   return parse_GPGGA(res)
end

local function stop()
   mdm_hnd.tryAT"+CGPSOUT=0"
end

local function off()
   stop()
   --   mdm_hnd.tryAT"+CGNSPWR=0"
   mdm_hnd.tryAT"+CGPSPWR=0"
end

return {on=init, start=start, stop=stop, init=init, off=off, fix=fix}
