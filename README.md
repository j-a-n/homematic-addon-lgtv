# HomeMatic addon to control LG WebOS Smart TV

## Prerequisites
* This addon depends on CUxD
* Power on is done by Wake On LAN, you will have to turn this feature on in your TVs settings (General => Mobile TV On => On)

## Installation / configuration
* Download [addon package](https://github.com/j-a-n/homematic-addon-lgtv/raw/master/hm-lgtv.tar.gz)
* Install addon package on ccu via system control
* Open LG-TV addon configuration in system control and add your TVs ( (http://<ccu-ip>/addons/lgtv/index.html))
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
The tv-id is an integer which is displayed on the addon's system control

### Commands

command                    | description
---------------------------| -----------------------------
`power_on`                   | power on tv
`power_off`                  | power off tv
`set_volume <level>`         | set volume to level
`volume_up`                  | turn up volume
`volume_down`                | turn down volume
`mute`                       | mute audio
`unmute`                     | unmute audio
`get_channels`               | get channel list
`open_channel <channel-id>`  | open channel by id
`channel_up`                 | channel up
`channel_down`               | channel down
`get_inputs`                 | get external input list
`switch_input <input-id>`    | switch input
`play`                       | play
`pause`                      | pause
`stop`                       | stop
`rewind`                     | rewind
`fast_forward`               | fast_forward
`show_message <text>`        | show message on screen
`get_apps`                   | get app list
`launch_app <app-id>`        | launch app
`request <uri> [payload]`    | send request

The `request` command can be use to send a raw request.
You can find a (possibly uncomplete) list of possible requests in the [lgtv2 npm package documentation](https://www.npmjs.com/package/lgtv2).

### Examples
Power on TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 power_on`

Turn up volume (+1) on TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 volume_up`

Set volume to 20 on TV 2:  
`/usr/local/addons/lgtv/lgtv.tcl 2 set_volume 20`

Open tv channel on TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 open_channel 7_23_1237_1237_1101_28107_1`

Switch input to HDMI-1 on TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 switch_input HDMI_1`

Show message on screen of TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 show_message 'Hello world!'`

Start Netflix-App on TV 1:  
`/usr/local/addons/lgtv/lgtv.tcl 1 launch_app netflix`

Pause playback on TV 1 via request uri:  
`/usr/local/addons/lgtv/lgtv.tcl 1 request ssap://media.controls/pause`

Mute TV 1 via request uri:  
`/usr/local/addons/lgtv/lgtv.tcl 1 request ssap://audio/setMute '{"mute":true}'`
