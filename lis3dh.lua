local sda = pio.GPIO14 -- Should be 23, but Huzzah has a problem with that.
local scl = pio.GPIO22
local int1pin = pio.GPIO27
local l3
local l3addr = 0x19

local function wreg(reg,val)
   l3:start()
   l3:address(l3addr,false)
   l3:write(reg,val)
   l3:stop()
end

local function rreg(reg)
   l3:start()
   l3:address(l3addr,false)
   l3:write(reg)
   l3:start()
   l3:address(l3addr,true)
   local val = l3:read()
   l3:stop()
   return val
end

local function cfg_int1()
   wreg(0x21, 0x01)		-- reg2: hp filter
   wreg(0x22, 0x40)		-- reg3: ia1 enable
   wreg(0x23, 0x90)		-- 4g
   wreg(0x24, 0x0a)		-- latch on INT1 and INT2
   wreg(0x30, 0x2a)		-- INT1_CFG
   wreg(0x32, 0x02)		-- INT1_THS
   wreg(0x33, 0x05)		-- INT_DURATTION 5 seconds
end

local function is_moving()
   return (rreg(0x31) & 0x40) == 0x40
end

local function poll()
   l3:start()
   l3:address(l3addr,false)
   l3:stop()
end

local function activate10hz()
   wreg(0x20,0x2f)
end

local function init()
   pio.pin.setdir(pio.INPUT, int1pin)
   i2c.setpins(i2c.I2C0, sda, scl)
   l3 = i2c.attach(i2c.I2C0, i2c.MASTER)
   poll()
   thread.sleepms(50)
   cfg_int1()
   activate10hz()
   return l3
end


local function id()
   l3:start()
   l3:address(l3addr,false)
   l3:write(0x0F)
   l3:start()
   l3:address(l3addr,true)
   local id = l3:read()
   l3:stop()
   return id
end

return { init=init, id=id, poll=poll, rreg=rreg, wreg=wreg, is_moving = is_moving,
	 cfg_int1 = cfg_int1, int1pin = int1pin }
