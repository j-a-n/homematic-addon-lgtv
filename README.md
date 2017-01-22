# HomeMatic addon to control LG WebOS Smart TV

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
 * Select CMD_EXEC
 * Set CMD_SHORT to ````/usr/local/addons/lgtv/lgtv.tcl <tv-id> <command> [parameter]````
  * i.e: ````/usr/local/addons/lgtv/lgtv.tcl 1 power_on````
