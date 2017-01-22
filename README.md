# HomeMatic addon to control LG WebOS Smart TV

## Prerequisites
* This addon depends on CUxD
* Power on is done by Wake On LAN, you will have to turn this feature on in your TVs settings (General => Mobile TV On => On)

## Installation / configuration

* Download [addon package](https://github.com/j-a-n/homematic-addon-lgtv/raw/master/hm-lgtv.tar.gz)
* Install addon package on ccu via system control
* Open LG-TV addon configuration in system control and add your TVs
* Create new (40) 16-channel universal control device in CUxD
 * Serialnumber: choose a free one
 * Name: choose one, i.e: `LG-TV`
 * Device-Icon: whatever you want
 * Control: KEY
* Configure new device in HomeMatic Web-UI
* Configure a device channel for each TV and command you want to use
 * Select CMD_EXEC
 * Set CMD_SHORT to `/usr/local/addons/lgtv/lgtv.tcl <tv-id> <command> [parameter]` (see usage for details)

## lgtv.tcl usage
`/usr/local/addons/lgtv/lgtv.tcl <tv-id> <command> [parameter]`

### tv-id
The tv-id is an integer which is displayed on the LG-TV system control

### Commands

command                 | description
------------------------| -----------------------------
`power_on`                | power on tv
`power_off`               | power off tv
`set_volume <level>`      | set volume to LEVEL
`show_message <text>`     | show message on screen
`get_apps`                | get app list
`lauch_app <app_id>`      | launch app
`request <uri> [payload]` | send request

The `request` command can be use to send a raw request.
You can find a (possibly uncomplete) list of possible requests in the [lgtv2 npm package documentation](https://www.npmjs.com/package/lgtv2).

### Examples
Power on TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 power_on`

Set volume to 20 on TV 2:  
`/usr/local/addons/lgtv/lgtv.tcl 2 set_volume 20`

Pause playback on TV 1 via request uri:  
`/usr/local/addons/lgtv/lgtv.tcl 1 request ssap://media.controls/pause`

Mute TV 1 via request uri:  
`/usr/local/addons/lgtv/lgtv.tcl 1 request ssap://audio/setMute '{"mute":true}'`
