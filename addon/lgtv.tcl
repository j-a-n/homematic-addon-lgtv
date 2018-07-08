#!/bin/tclsh

#  HomeMatic addon to control LG WebOS Smart TV
#
#  Copyright (C) 2017  Jan Schneider <oss@janschneider.net>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

source /usr/local/addons/lgtv/lib/lgtv.tcl

proc usage {} {
	global argv0
	puts stderr ""
	puts stderr "usage: ${argv0} <tv-id> <command> \[parameter\]..."
	puts stderr ""
	puts stderr "possible commands:"
	puts stderr "  power_on                    power on tv"
	puts stderr "  power_off                   power off tv"
	puts stderr "  set_volume <level>          set volume to level"
	puts stderr "  volume_up                   turn up volume"
	puts stderr "  volume_down                 turn down volume"
	puts stderr "  mute                        mute audio"
	puts stderr "  unmute                      unmute audio"
	puts stderr "  get_channels                get channel list"
	puts stderr "  open_channel <channel-id>   open channel by id"
	puts stderr "  channel_up                  channel up"
	puts stderr "  channel_down                channel down"
	puts stderr "  get_inputs                  get external input list"
	puts stderr "  switch_input <input-id>     switch input"
	puts stderr "  play                        play"
	puts stderr "  pause                       pause"
	puts stderr "  stop                        stop"
	puts stderr "  rewind                      rewind"
	puts stderr "  fast_forward                fast_forward"
	puts stderr "  show_message <text>         show message on screen"
	puts stderr "  get_apps                    get app list"
	puts stderr "  launch_app <app-id>         launch app"
	puts stderr "  request <uri> \[payload]\     send request"
	puts stderr ""
	puts stderr "Power on is done by Wake On LAN, you will have to turn this feature on in TVs settings."
	puts stderr "General => Mobile TV On => On"
}

proc main {} {
	global argc
	global argv
	
	set tv_id [string tolower [lindex $argv 0]]
	set cmd [string tolower [lindex $argv 1]]
	
	if {$cmd == ""} {
		usage
		exit 1
	}
	set res [eval lgtv::tv_command [list $tv_id] [list $cmd] [lrange $argv 2 end]]
	puts $res
}

if { [ catch {
	#catch {cd [file dirname [info script]]}
	main
} err ] } {
	puts stderr "ERROR: $err"
	exit 1
}
exit 0


