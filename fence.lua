local deg_rad = math.pi/180
local earth_rad_meters = 6372797.560856

local function arcrads(pointA,pointB)
   local latarc = (pointA[1] - pointB[1]) * deg_rad
   local lonarc = (pointA[2] - pointB[2]) * deg_rad
   local latH = math.sin(latarc * 0.5)
   latH = latH * latH
   local lonH = math.sin(lonarc * 0.5)
   lonH = lonH * lonH
   local tmp = math.cos(pointA[1]*deg_rad) * math.cos(pointB[1]*deg_rad)
   return 2.0 * math.asin(math.sqrt(latH + tmp*lonH))
end

local function meters(pointA, pointB)
   return earth_rad_meters * arcrads(pointA,pointB)
end

local function check_fences(Fences, point)
   for idx,fence in ipairs(Fences) do
      local distance = meters(point,fence.circle.coords)
      if distance <= fence.circle.meters then
	 return idx,fence.nobeacon,fence.checkrate
      end
   end
   return 0,nil,nil
end

return { meters=meters, check_fences=check_fences }

