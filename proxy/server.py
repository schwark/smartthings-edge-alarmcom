import logging
from keyrings.cryptfile.cryptfile import CryptFileKeyring
from http.client import HTTPConnection
HTTPConnection.debuglevel = 0

logging.basicConfig(filename="/tmp/alarmcom.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.NOTSET)
logging.getLogger().setLevel(logging.DEBUG)
requests_log = logging.getLogger("requests.packages.urllib3")
requests_log.setLevel(logging.DEBUG)
requests_log.propagate = True
ssdpy_log = logging.getLogger("ssdpy.server")
ssdpy_log.setLevel(logging.WARNING)
ssdpy_log.propagate = True


import argparse
from getpass import getpass
import cherrypy
import keyring
from alarm import AlarmDotCom
from ssdpy import SSDPServer
from alarm import AlarmDotCom
import threading
import socket

class AlarmComService(object):
    def __init__(self):
        self.panel = AlarmDotCom()
    
    @cherrypy.expose
    @cherrypy.tools.json_out()
    def index(self):
        return {'status': 'up'}

    @cherrypy.expose
    @cherrypy.tools.json_out()
    def status(self):
        return {'status': self.panel.update()}

    @cherrypy.expose
    @cherrypy.tools.json_out()
    @cherrypy.tools.json_in()
    def armStay(self):
        flags = (hasattr(cherrypy.request, 'json') and cherrypy.request.json) or {}
        return {'status': self.panel.arm_stay(flags)}

    @cherrypy.expose
    @cherrypy.tools.json_out()
    @cherrypy.tools.json_in()
    def armAway(self):
        flags = (hasattr(cherrypy.request, 'json') and cherrypy.request.json) or {}
        return {'status': self.panel.arm_away(flags)}

    @cherrypy.expose
    @cherrypy.tools.json_out()
    def disarm(self):
        return {'status': self.panel.disarm()}

def get_ip():
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        try:
            # doesn't even have to be reachable
            s.connect(('8.8.8.8', 80))
            IP = s.getsockname()[0]
        except Exception:
            IP = '127.0.0.1'
        finally:
            s.close()
        return IP

def start_cherry():
    cherrypy.server.socket_host = '0.0.0.0'
    cherrypy.quickstart(AlarmComService())    

def start_ssdp():
    server = SSDPServer("uuid:de8a5619-2603-40d1-9e21-1967952d7f86", device_type="urn:SmartThingsCommunity:device:AlarmComProxy:1", location='http://'+get_ip()+':'+str(cherrypy.server.socket_port)+'/')
    server.serve_forever()
        

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", help="force update credentials",
                        action="store_true")
    parser.add_argument("--nossdp", help="does not start ssdp server",
                        action="store_true")
    args = parser.parse_args()
    
    kr = CryptFileKeyring()
    kr.keyring_key = getpass('Keyring Passphrase: ')
    keyring.set_keyring(kr)
    
    panel_id = keyring.get_password(AlarmDotCom.SERVICE_ID, AlarmDotCom.PANEL_KEY)
    if(not panel_id):
        username = keyring.get_password(AlarmDotCom.SERVICE_ID, AlarmDotCom.USERNAME_KEY)
        password = keyring.get_password(AlarmDotCom.SERVICE_ID, AlarmDotCom.PASSWORD_KEY)
        if(not username or not password or args.force):
            username = getpass("Alarm.com username: ")
            password = getpass("Alarm.com password: ")
            keyring.set_password(AlarmDotCom.SERVICE_ID, AlarmDotCom.USERNAME_KEY, username)
            keyring.set_password(AlarmDotCom.SERVICE_ID, AlarmDotCom.PASSWORD_KEY, password)

    threads = [threading.Thread(target=start_cherry)]
    if(not args.nossdp):
        threads.append(threading.Thread(target=start_ssdp))

    for th in threads:
        th.start()
        print(f'threads {th} started')
        th.join(0.1)