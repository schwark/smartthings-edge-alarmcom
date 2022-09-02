# SmartThings Alarm.com integration via local Proxy

This repo contains 

a) direct implementation of the Alarm.com integration which does not work today due to the security model preventing access to alarm.com from a LAN driver, but hopefully it will work someday

b) proxy based alarm.com integration that requires a proxy server that needs to be run somewhere in the same network as your SmartThings hub. It is written in python so can run anywhere python runs, but a raspberrypi is usually a good place to do it - so I am going to say raspberrypi in the README below, but you can host in anywhere including maybe your synology NAS, etc.

If you have a Mac that is on all the time, that works too. Mac's already have python installed as well.

The rest of this README is instructions on how to get the proxy based integration working

## Proxy Installation

Copy the `src/proxy` directory on the raspberypi anywhere

```
sudo ufw allow 8080    # if you have ufw enabled on the raspberrypi
cd <directory-where-you-copied-code>
pip install -r requirements.txt
supervisord -c supervisord.conf
supervisorctl update
<wait 1 s>
supervisorctl fg alarmcomproxy

Keyring Passphrase:  
<enter a passphrase to encrypt storage of your password> 
(REMEMBER THIS - need to type every time startup)

Alarm.com username:  
<enter your alarm.com username> (asked only once, stored encrypted with above passphrase)

Alarm.com password:  
<enter your alarm.com password> (asked only once, stored encrypted with above passphrase)

<wait for 30s to a couple of mins (especially on raspberrypi) till you see something like this below...>

ENGINE Bus STARTED

# now type in..
<Ctrl-C>
```

## Driver Installation

1. Click on [Driver Invite Link] (https://bestow-regional.api.smartthings.com/invite/VD2NLgQwpNj5)
2. Login to your SmartThings Account
3. Follow the flow to Accept Terms
4. Enroll your Hub
5. Install the Driver you want from the Available Drivers Button

## App Configuration

1. Now go to your SmartThings app and **Add a Device** > **Scan Nearby**.

2. After a couple of minutes, a new device should show up for your **Alarm.com Panel** that is automatically added

The **Alarm.com Panel** device in SmartThings app has 3 settings in the Settings section of the device that control Silent Arming, Forcing Bypass of open sensors, and arming with a No Entry Delay

The panel can also be operated like a switch - turning it on puts the alarm in ArmStay mode, and turning it off disarms the alarm.




