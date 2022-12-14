# SmartThings Alarm.com integration via local Proxy

This repo contains a proxy based alarm.com integration that requires a proxy server that needs to be run somewhere in the same network as your SmartThings hub. It is written in python so can run anywhere python runs, but a raspberrypi is usually a good place to do it - so I am going to say raspberrypi in the README below, but you can host in anywhere including maybe your synology NAS, etc. 

When someday access to alarm.com will work directly from the driver, the same driver should be able to work without the proxy.

The rest of this README is instructions on how to get the proxy based integration working.

There are three ways to install the proxy - preferred is to just download an executable and run it. However, it is also possible to run it as a python script if you do not want to run an executable - one without docker (non-docker), which is a little more involved. Or you can install docker and run the docker container (simpler). You do **ONLY ONE** of the Executable, Non-Docker Python or the Docker Python - not all of them.


## Preferred Proxy Installation (Platform Specific Executable)

Download the [appropriate release](https://github.com/schwark/stproxy) of the stproxy and run it. See the README on the page to decide which executable you need. To run it.. 

```
stproxy-<os>-<arch>
```


## Alternative #2: Proxy Installation (Docker Python)
Install docker on your [preferred platform](https://docs.docker.com/get-docker/) or on most unix based platforms like raspberry pi by running 

```
sudo apt-get update && sudo apt-get full-upgrade
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker ${USER}
sudo systemctl enable docker
```

After docker is installed, reboot and run the following to run the proxy

```
docker run -td -p 8081:8081 -p 1900:1900/udp --net=host schwark/stproxy
```


## Alternative #3: Proxy Installation (Non-Docker Python)

### Python Installation 

**On a raspberry pi, or other Linux machine**

Nothing needed - your machine already has python. If by any chance it does not

```
sudo apt-get install python3

python3 -m ensurepip --upgrade
```

**On a Mac** 
```
# try to see if you already have python - python or python3 should be found, if not do the following
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install python
```

**On a Windows machine**

Download from [Python Download](https://www.python.org/downloads/) page and install

That takes care of installing python..

### Proxy Code Installation

Download this code repo as a [zip file](https://github.com/schwark/smartthings-edge-alarmcom/archive/refs/heads/main.zip)

Unzip the zip file. Make a note of where you downloaded and unzip'ed the file. The `proxy` directory inside is what you want to remember the location of. Open a Terminal (Mac OS X) or Command Prompt (Windows) or shell (linux)

```
sudo ufw allow 8081    # only on linux and if you have ufw enabled on the raspberrypi
cd <proxy-directory--wherever-you-copied it>
pip3 install -r requirements.txt
supervisord -c supervisord.conf
supervisorctl update
```

To stop the proxy

```
supervisorctl stop stproxy
```


## Driver Installation

1. Click on [Driver Invite Link](https://bestow-regional.api.smartthings.com/invite/VD2NLgQwpNj5)
2. Login to your SmartThings Account
3. Follow the flow to Accept Terms
4. Enroll your Hub
5. Install the Driver you want from the Available Drivers Button


## App Configuration

1. Now go to your SmartThings app and **Add a Device** > **Scan Nearby**.

2. After a couple of minutes, a new device should show up for your **Alarm.com Panel** that is automatically added

3. Go to **Alarm.com Panel** device in SmartThings app, and click on three vertical dots on the top right, and click on **Settings**

4. Enter username and password for Alarm.com. 

5. OPTIONAL: You can also manually add the IP address of the proxy **if using the Docker proxy installation** as sometimes the proxy is not automatically discovered when the proxy is running in a docker container.

6. OPTIONAL: You can turn on Add Sensors options if you want a SmartThings Contact Sensor added for each of the door/window sensors of your alarm

7. OPTIONAL: You can also modify settings of the device that control Silent Arming, Forcing Bypass of open sensors, and arming with a No Entry Delay. 

8. Now go back to the device page, and pull down to refresh

9. The device should now show switch state and Security mode state - you are done if you did not choose **Add Sensors** option in **Settings**

10. If you turned on **Add Sensors** options in the **Settings** page, go back to **Add a Device** > **Scan Nearby**

11. This time a SmartThings contact sensor should be added for each of the sensors in your Alarm system

12. Now this is done - it will take about 5 minutes for the status of all the sensors to be updated, and it will be updated every 5 min thereafter as well


The panel can also be operated like a switch - turning it on puts the alarm in ArmStay mode, and turning it off disarms the alarm.
