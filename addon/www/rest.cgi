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

# env:
#  CONTENT_LENGTH
#  DOCUMENT_ROOT
#  GATEWAY_INTERFACE
#  HTTP_ACCEPT
#  HTTP_ACCEPT_ENCODING
#  HTTP_ACCEPT_LANGUAGE
#  HTTP_CONNECTION
#  HTTP_HOST
#  HTTP_UPGRADE_INSECURE_REQUESTS
#  HTTP_USER_AGENT
#  QUERY_STRING
#  REDIRECT_STATUS
#  REMOTE_ADDR
#  REMOTE_PORT
#  REQUEST_METHOD
#  REQUEST_URI
#  SCRIPT_FILENAME
#  SCRIPT_NAME
#  SERVER_ADDR
#  SERVER_NAME
#  SERVER_PORT
#  SERVER_PROTOCOL
#  SERVER_SOFTWARE
#  TZ

proc json_string {str} {
	set replace_map {
		"\"" "\\\""
		"\\" "\\\\"
		"\b"  "\\b"
		"\f"  "\\f"
		"\n"  "\\n"
		"\r"  "\\r"
		"\t"  "\\t"
	}
	return "[string map $replace_map $str]"
}

proc process {} {
	global env
	if { [info exists env(QUERY_STRING)] } {
		set query $env(QUERY_STRING)
		set data ""
		if { [info exists env(CONTENT_LENGTH)] } {
			set data [read stdin $env(CONTENT_LENGTH)]
		}
		set path [split $query {/}]
		set plen [expr [llength $path] - 1]
		#error ">${query}< | >${path}< | >${plen}<" "Debug" 500
		if {[lindex $path 1] == "lookup-mac-address"} {
			set ip_or_host [string range $data 1 end-1]
			set mac_address [lgtv::lookup_mac_address $ip_or_host]
			return "\"${mac_address}\""
		} elseif {[lindex $path 1] == "lookup-ip-address"} {
			set ip_or_host [string range $data 1 end-1]
			set ip_address [lgtv::lookup_ip_address $ip_or_host]
			return "\"${ip_address}\""
		} elseif {[lindex $path 1] == "command"} {
			set tv_id [lindex $path 2]
			regexp {\"command\"\s*:\s*\"([^\"]+)\"} $data match command
			regexp {\"arguments\"\s*:\s*\[([^\]]+)\]} $data match arguments
			set arglist {}
			if { [info exists arguments] } {
				foreach a [split $arguments ","] {
					regexp {(exec|eval)} $a amatch
					if {[info exists amatch]} {
						error "Forbidden: ${amatch}" "Forbidden" 403
					}
					lappend arglist [expr $a]
				}
			}
			set res [eval lgtv::tv_command [list $tv_id] [list $command] [lrange $arglist 0 end]]
			return $res
		} elseif {[lindex $path 1] == "config"} {
			if {$plen == 1} {
				if {$env(REQUEST_METHOD) == "GET"} {
					return [lgtv::get_config_json]
				}
			} elseif {[lindex $path 2] == "tv"} {
				if {$plen == 3} {
					if {$env(REQUEST_METHOD) == "PUT"} {
						set id [lindex $path 3]
						#error "${data}" "Debug" 500
						regexp {\"name\"\s*:\s*\"([^\"]+)\"} $data match name
						regexp {\"ip\"\s*:\s*\"([^\"]+)\"} $data match ip
						regexp {\"mac\"\s*:\s*\"([^\"]+)\"} $data match mac
						lgtv::create_tv $id $name $ip $mac
						return "\"TV ${id} successfully created\""
					} elseif {$env(REQUEST_METHOD) == "DELETE"} {
						set id [lindex $path 3]
						lgtv::delete_tv $id
						return "\"TV ${id} successfully deleted\""
					}
				}
			}
		}
	}
	error "invalid request" "Not found" 404
}

if [catch {process} result] {
	set status 500
	if { [info exists $errorCode] } {
		set status $errorCode
	}
	puts "Content-Type: application/json"
	puts "Status: $status";
	puts ""
	set result [json_string $result]
	puts -nonewline "\{\"error\":\"${result}\"\}"
} else {
	puts "Content-Type: application/json"
	puts "Status: 200 OK";
	puts ""
	puts -nonewline $result
}

