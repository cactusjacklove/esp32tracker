Years ago, I was looking for a low cost GPS tracker to keep track of a family
member who was in the early stages of dementia. She still drove her car and only
had small memory lapses. But when they happened, she would get lost and forget
where she was.  We found a product but it had a costly monthly subscription.
I thought I could do better (for less).

So, I started working on a basic GPS tracker that used SMS (instead of a web based
map server).  The idea was to notify us whenever she left her neighborhood and
ventured out on the highway or unfamiliar places.

I looked at my ESP32 dev boards, found LuaRTOS (https://github.com/whitecatboard/Lua-RTOS-ESP32) and thought that I could do a decent tracker with that and a SIM808
board.

This was to be part of my Elder monitoring stuff (including stove monitoring, etc).

Well, by the time I got something work, she was no longer able to drive, so the code
sat around for a while.

But, my tracking itch never got satisfied...

So here is the code, updated to the latest LuaRTOS and released as GPL
(it's a mess, I'll be cleaning it up and improving it).

Hardware, configuration and usage instructions are forthcoming!
Enjoy and use resposibly.
