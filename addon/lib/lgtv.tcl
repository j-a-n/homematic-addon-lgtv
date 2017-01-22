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

source /usr/local/addons/lgtv/lib/ini.tcl

namespace eval lgtv {
	variable ini_file "/usr/local/addons/lgtv/etc/lgtv.conf"
	variable log_file "/usr/local/addons/lgtv/log.txt"
	variable etherwake "/usr/local/addons/cuxd/extra/ether-wake"
}

proc ::lgtv::convert_string_to_hex {str} {
	binary scan $str H* hex
	return $hex
}

proc ::lgtv::lookup_ip_address {hostname} {
	set ip_address ""
	regexp {^([a-zA-z0-9\-\.]+)$} $hostname match hn
	# prevent command injection => check hostname
	if { [info exists hn] } {
		set status [catch {exec nslookup $hn} result]
		if {$status == 0} {
			set lines [split $result "\n"]
			foreach line $lines {
				regexp {\s([0-9\.]+)\s+([a-zA-z0-9\-\.]+)\s*$} $line match i h
				if { [info exists h] } {
					if {$h == $hostname} {
						set ip_address $i
					}
				}
			}
		}
	}
	return $ip_address
}

proc ::lgtv::lookup_mac_address {ip_or_host} {
	set ip_address ""
	set mac_address ""
	regexp {^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$} $ip_or_host match
	if { [info exists match] } {
		set ip_address $ip_or_host
	} else {
		set ip_address [lookup_ip_address $ip_or_host]
	}
	if {$ip_address != ""} {
		set status [catch {exec ping -w1 -t1 $ip_address} result]
		set fp [open "/proc/net/arp" r]
		set file_data [read $fp]
		set data [split $file_data "\n"]
		foreach line $data {
			regexp {^([\d\.]+)\s+\S+\s+\S+\s+([0-9a-f:]+)\s+} $line match ip mac
			if { [info exists ip] } {
				if {$ip == $ip_address && $mac != "00:00:00:00:00:00"} {
					set mac_address $mac
				}
			}
		}
		close $fp
	}
	return $mac_address
}

proc ::lgtv::get_config_json {} {
	variable ini_file
	#error ">${ini_file}<" "Debug" 500
	set ini [ini::open $ini_file r]
	set json "\{\"tvs\":\["
	set count 0
	foreach section [ini::sections $ini] {
		set idx [string first "tv_" $section]
		if {$idx == 0} {
			set count [ expr { $count + 1} ]
			append json "{\"id\":\"${section}\","
			foreach key [ini::keys $ini $section] {
				set value [::ini::value $ini $section $key]
				set value [json_string $value]
				append json "\"${key}\":\"${value}\","
			}
			set json [string range $json 0 end-1]
			append json "},"
		}
	}
	if {$count > 0} {
		set json [string range $json 0 end-1]
	}
	append json "\]\}"
	return $json
}

proc ::lgtv::create_tv {tv_id name ip mac} {
	variable ini_file
	set ini [ini::open $ini_file r+]
	ini::set $ini $tv_id "name" $name
	ini::set $ini $tv_id "ip" $ip
	ini::set $ini $tv_id "mac" $mac
	ini::set $ini $tv_id "port" 3000
	ini::commit $ini
}

proc ::lgtv::set_client_key {tv_id key} {
	variable ini_file
	set ini [ini::open $ini_file r+]
	ini::set $ini $tv_id "key" $key
	ini::commit $ini
}

proc ::lgtv::get_tv {tv_id} {
	variable ini_file
	set tv(id) ""
	set ini [ini::open $ini_file r]
	foreach section [ini::sections $ini] {
		set idx [string first $tv_id $section]
		if {$idx == 0} {
			set tv(id) $tv_id
			foreach key [ini::keys $ini $section] {
				set value [::ini::value $ini $section $key]
				set tv($key) $value
			}
		}
	}
	if {![info exists tv(key)]} {
		set tv(key) ""
	}
	return [array get tv]
}

proc ::lgtv::delete_tv {tv_id} {
	variable ini_file
	set ini [ini::open $ini_file r+]
	ini::delete $ini $tv_id
	ini::commit $ini
}

proc ::lgtv::mask_message {mask msg} {
	binary scan $msg I*c* words bytes
	set masked_words {}
	set masked_bytes {}
	for {set i 0} {$i < [llength $words]} {incr i} {
		lappend masked_words [expr {[lindex $words $i] ^ $mask}]
	}
	for {set i 0} {$i < [llength $bytes]} {incr i} {
		lappend masked_bytes [expr {[lindex $bytes $i] ^ ($mask >> (24 - 8 * $i))}]
	}
	return [binary format I*c* $masked_words $masked_bytes]
}

proc ::lgtv::receive_websocket_message {sock} {
	binary scan [read $sock 2] S header
	set opcode [expr {$header >> 8 & 0xf}]
	set mask [expr {$header >> 7 & 0x1}]
	set len [expr {$header & 0x7f}]
	set reserved [expr {$header >> 12 & 0x7}]
	if { $len == 126 } {
		binary scan [read $sock 2] S len
	} elseif { $len == 127 } {
		binary scan [read $sock 8] W len
	}
	set msg [read $sock $len]
	#write_log 3 "<<< $msg"
	return $msg
}

proc ::lgtv::send_websocket_message {sock msg} {
	# https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers
	# Frame format:
	#
	#  0               1               2               3
	#  1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8
	# +-+-+-+-+-------+-+-------------+-------------------------------+
	# |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
	# |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
	# |N|V|V|V|       |S|             |   (if payload len==126/127)   |
	# | |1|2|3|       |K|             |                               |
	# +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
	# |     Extended payload length continued, if payload len == 127  |
	# + - - - - - - - - - - - - - - - +-------------------------------+
	# |                               |Masking-key, if MASK set to 1  |
	# +-------------------------------+-------------------------------+
	# | Masking-key (continued)       |          Payload Data         |
	# +-------------------------------- - - - - - - - - - - - - - - - +
	# :                     Payload Data continued ...                :
	# + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	# |                     Payload Data continued ...                |
	# +---------------------------------------------------------------+
	#
	
	fconfigure $sock -translation binary -blocking on
	fileevent $sock readable [list [namespace current]::__receiver $sock]
	
	set fin 1
	set opcode 1
	set mask 1
	set msg [encoding convertto utf-8 $msg]
	
	set header [binary format c [expr {!!$fin << 7 | $opcode}]]
	
	set mlen [string length $msg]
	if {$mlen < 126} {
		set plen $mlen
	} elseif {$mlen < 65536} {
		set plen 126
	} else {
		set plen 127
	}
	append header [binary format c [expr {!!$mask << 7 | $plen}]]
	
	if {$mlen > 125} {
		if {$mlen < 65536} {
			append header [binary format S $mlen]
		} else {
			append header [binary format W $mlen]
		}
	}
	
	set mask [expr {int(rand()*1073741824)}]
	append header [binary format I $mask]
	
	#write_log 3 ">>> $msg"
	
	set msg [mask_message $mask $msg]
	#set mlen [string length $msg]
	#puts "header: [convert_string_to_hex $header]"
	#puts "msg: [convert_string_to_hex $msg]"
	puts -nonewline $sock $header$msg
	flush $sock
}

proc ::lgtv::connect {tv_id} {
	set atv [get_tv $tv_id]
	array set tv $atv
	if {$tv(id) == ""} {
		error "TV ${tv_id} not configured"
	}
	if {$tv(ip) == ""} {
		error "TV ${tv_id} ip address unknown"
	}
	#write_log 2 "connect to ${tv(ip)}:${tv(port)}"
	
	set sock [socket $tv(ip) $tv(port)]
	
	puts $sock "GET / HTTP/1.1"
	puts $sock "Host: ${tv(ip)}:${tv(port)}"
	puts $sock "User-Agent: cuxd"
	puts $sock "Upgrade: WebSocket"
	puts $sock "Connection: Upgrade"
	puts $sock "Sec-WebSocket-Key: BqBuU1+AHxySiVZPpzSLVw=="
	puts $sock "Sec-WebSocket-Version: 13"
	puts $sock ""
	
	flush $sock
	
	while {![eof $sock]} {
		gets $sock line
		if {$line == ""} {
			break
		}
	}

	set cmd "\{
		\"type\": \"register\",
		\"payload\": \{
			\"client-key\": \"${tv(key)}\",
			\"pairingType\": \"PROMPT\",
			\"forcePairing\": false,
			\"manifest\": \{
				\"permissions\": \[
					\"LAUNCH\",
					\"LAUNCH_WEBAPP\",
					\"APP_TO_APP\",
					\"CLOSE\",
					\"TEST_OPEN\",
					\"TEST_PROTECTED\",
					\"CONTROL_AUDIO\",
					\"CONTROL_DISPLAY\",
					\"CONTROL_INPUT_JOYSTICK\",
					\"CONTROL_INPUT_MEDIA_RECORDING\",
					\"CONTROL_INPUT_MEDIA_PLAYBACK\",
					\"CONTROL_INPUT_TV\",
					\"CONTROL_POWER\",
					\"READ_APP_STATUS\",
					\"READ_CURRENT_CHANNEL\",
					\"READ_INPUT_DEVICE_LIST\",
					\"READ_NETWORK_STATE\",
					\"READ_RUNNING_APPS\",
					\"READ_TV_CHANNEL_LIST\",
					\"WRITE_NOTIFICATION_TOAST\",
					\"READ_POWER_STATE\",
					\"READ_COUNTRY_INFO\"
				\],
				\"appVersion\": \"1.1\",
				\"manifestVersion\": \"1\",
				\"signed\": \{
					\"vendorId\": \"com.lge\",
					\"localizedAppNames\": \{
						\"\": \"LG Remote App\",
						\"zxx-XX\": \"\\u041b\\u0413 R\\u044d\\u043cot\\u044d A\\u041f\\u041f\",
						\"ko-KR\": \"\\ub9ac\\ubaa8\\ucee8 \\uc571\"
					\},
					\"permissions\": \[
						\"TEST_SECURE\",
						\"CONTROL_INPUT_TEXT\",
						\"CONTROL_MOUSE_AND_KEYBOARD\",
						\"READ_INSTALLED_APPS\",
						\"READ_LGE_SDX\",
						\"READ_NOTIFICATIONS\",
						\"SEARCH\",
						\"WRITE_SETTINGS\",
						\"WRITE_NOTIFICATION_ALERT\",
						\"CONTROL_POWER\",
						\"READ_CURRENT_CHANNEL\",
						\"READ_RUNNING_APPS\",
						\"READ_UPDATE_INFO\",
						\"UPDATE_FROM_REMOTE_APP\",
						\"READ_LGE_TV_INPUT_EVENTS\",
						\"READ_TV_CURRENT_TIME\"
					\],
					\"localizedVendorNames\": \{
						\"\": \"LG Electronics\"
					\},
					\"appId\": \"com.lge.test\",
					\"serial\": \"2f930e2d2cfe083771f68e4fe7bb07\",
					\"created\": \"20140509\"
				\},
				\"signatures\": \[\{
					\"signatureVersion\": 1,
					\"signature\": \"eyJhbGdvcml0aG0iOiJSU0EtU0hBMjU2Iiwia2V5SWQiOiJ0ZXN0LXNpZ25pbmctY2VydCIsInNpZ25hdHVyZVZlcnNpb24iOjF9.hrVRgjCwXVvE2OOSpDZ58hR+59aFNwYDyjQgKk3auukd7pcegmE2CzPCa0bJ0ZsRAcKkCTJrWo5iDzNhMBWRyaMOv5zWSrthlf7G128qvIlpMT0YNY+n/FaOHE73uLrS/g7swl3/qH/BGFG2Hu4RlL48eb3lLKqTt2xKHdCs6Cd4RMfJPYnzgvI4BNrFUKsjkcu+WD4OO2A27Pq1n50cMchmcaXadJhGrOqH5YmHdOCj5NSHzJYrsW0HPlpuAx/ECMeIZYDh6RMqaFM2DXzdKX9NmmyqzJ3o/0lkk/N97gfVRLW5hA29yeAwaCViZNCP8iC9aO0q9fQojoa7NQnAtw==\"
				\}\]
			\}
		\}
	\}"

	send_websocket_message $sock $cmd
	set response ""
	for {set i 0} {$i <= 1} {incr i} {
		set response [receive_websocket_message $sock]
		regexp {"client-key"\s*:\s*"([a-f0-9]+)"} $response match key
		if {[info exists key]} {
			set_client_key $tv_id $key
			return $sock
		}
	}
	close $sock
	
	regexp {"error"\s*:\s*"([^"]+)"} $response match wserr
	if {[info exists wserr]} {
		error $wserr
	}
	error $response
}

proc ::lgtv::disconnect {sock} {
	close $sock
}

proc ::lgtv::request {tv_id uri {payload ""}} {
	set json "\{\"type\": \"request\", \"id\": \"request_1\", \"uri\": \"${uri}\""
	if {$payload != ""} {
		append json ", \"payload\": ${payload}"
	}
	append json "\}"
	
	set sock [connect $tv_id]
	send_websocket_message $sock $json
	set response [receive_websocket_message $sock]
	close $sock
	return $response
}

proc ::lgtv::power_on {tv_id} {
	variable etherwake
	set atv [get_tv $tv_id]
	array set tv $atv
	if {$tv(id) == ""} {
		error "TV ${tv_id} not configured"
	}
	if {$tv(mac) == ""} {
		error "TV ${tv_id} mac address unknown"
	}
	exec $etherwake $tv(mac)
	return "Wake On LAN magic packet sent to $tv(mac)"
}

proc ::lgtv::power_off {tv_id} {
	return [request $tv_id "ssap://system/turnOff"]
}

proc ::lgtv::set_volume {tv_id volume} {
	return [request $tv_id "ssap://audio/setVolume" "\{\"volume\": $volume\}"]
}

proc ::lgtv::show_message {tv_id msg} {
	set msg [string map { \" \\\" } $msg]
	return [request $tv_id "ssap://system.notifications/createToast" "\{\"message\": \"$msg\"\}"]
}

proc ::lgtv::get_apps {tv_id} {
	return [request $tv_id "ssap://com.webos.applicationManager/listLaunchPoints"]
}

proc ::lgtv::launch_app {tv_id, app_id} {
	return [request $tv_id "ssap://system.launcher/launch" "\{\"id\": \"$app_id\"\}"]
}

proc ::lgtv::tv_command {tv_id command args} {
	#error "${command} >${args}<" "Debug" 500
	if {$args != ""} {
		if {[llength $args] == 1} {
			set result [$command $tv_id [lindex $args 0]]
		} else {
			eval {set result [$command $tv_id $args]}
		}
	} else {
		eval {set result [$command $tv_id]}
	}
	return $result
}


