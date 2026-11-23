extends RefCounted

## The shaman's ritual (issue #20): it starts every PERIOD seconds of real time and lasts LENGTH; whoever
## stands in the circle round the shaman hut while it lasts is blessed for BLESSING seconds.
## Times and the blessing's effect are ASSUMPTION (D013): +25% max health on hunts.

const PERIOD := 3600
const LENGTH := 600
const BLESSING := 3600
const HEALTH_SHARE := 0.25
## Circle radius round the hut, metres.
const RADIUS := 6.0


static func active(now: int) -> bool:
	return now % PERIOD < LENGTH


## Seconds until the ritual starts (while it is off) or ends (while it is on).
static func seconds_left(now: int) -> int:
	return LENGTH - now % PERIOD if active(now) else PERIOD - now % PERIOD
