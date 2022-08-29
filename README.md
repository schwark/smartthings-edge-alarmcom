# SmartThings Alarm.com integration via local Proxy

This repo contains 

a) direct implementation of the Alarm.com integration which does not work today due to the security model preventing access to alarm.com from a LAN driver, but hopefully it will work someday

b) proxy based alarm.com integration that requires a proxy server that needs to be run somewhere in the same network as your SmartThings hub. It is written in python so can run anywhere python runs, but a raspberrypi is usually a good place to do it - so I am going to say raspberrypi in the README below, but you can host in anywhere including maybe your synology NAS, etc.

The rest of this README is instructions on how to get the proxy based integration working


1. Copy the `src/proxy` directory on the raspberypi anywhere

```
sudo ufw allow 8080    # if you have ufw enabled on the raspberrypi
pip install -r requirements.txt
python server.py --setup
```

This last step will ask you to enter the following

```
Keyring Passphrase:  <enter a passphrase to encrypt storage of your password> (need to type every time startup)
Alarm.com username:  <enter your alarm.com username> (asked only once, stored encrypted with above passphrase)
Alarm.com password:  <enter your alarm.com password> (asked only once, stored encrypted with above passphrase)

<wait for 30s to a couple of mins (especially on raspberrypi) till you see something like this below...>

19:45:05,210 ssdpy.server INFO Listening forever
```

2. Leave this running and now go to your SmartThings app and **Add a Device** > **Scan Nearby**.

3. After a couple of minutes, a new device should show up for your **Alarm.com Panel** that is automatically added

4. Exit the app

5. Go back to the raspberrypi and stop execution of the `python server.py --setup` program

```
supervisord -c supervisord.conf
supervisorctl update
<wait 1 s>
supervisorctl fg alarmcomproxy

Keyring Passphrase:  <enter the passphrase created the first time>
<wait 5s>
<Ctrl-C> 
```

6. You should be all set!

The **Alarm.com Panel** device in SmartThings app has 3 settings in the Settings section of the device that control Silent Arming, Forcing Bypass of open sensors, and arming with a No Entry Delay

The panel can also be operated like a switch - turning it on put the alarm in ArmStay mode, and turning it off disarms the alarm.




