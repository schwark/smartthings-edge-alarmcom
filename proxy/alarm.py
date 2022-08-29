import keyring
import logging
import requests
from browser import Browser
from time import time

log = logging.getLogger("alarmdotcom")
log.setLevel(logging.DEBUG)

class AlarmDotCom:
    SERVICE_ID = "alarmcom"
    USERNAME_KEY = "username"
    PASSWORD_KEY = "password"
    AFG_KEY = "afg"
    USER_KEY = "kender"
    SYSTEM_KEY = "systemkey"
    PANEL_KEY = "panelid"
    STATES = ['disarm', 'armStay', 'armAway']
    SESSION_TIMEOUT = 100
    
    def __init__(self) -> None:
        self.browser = Browser()
        self.reload = False
        self.user_id = None
        self.system_id = None
        self.panel_id = keyring.get_password(self.SERVICE_ID, self.PANEL_KEY)
        self.username = keyring.get_password(self.SERVICE_ID, self.USERNAME_KEY)
        self.password = keyring.get_password(self.SERVICE_ID, self.PASSWORD_KEY)
        self.afg = None
        self.last_request = None
                    
    def update_state(self):
        cookies = requests.utils.dict_from_cookiejar(self.browser.session.cookies)
        if('afg' in cookies):
            afg = cookies['afg']
            if(afg and self.afg != afg):
                self.afg = afg
        
    def set_panel_id(self, panel_id):
        if(panel_id):
            self.panel_id = str(panel_id)
            keyring.set_password(self.SERVICE_ID, self.PANEL_KEY, self.panel_id)
        log.debug("saved panel id")
        
    def set_system_id(self, system_id):
        if(system_id):
            self.system_id = str(system_id)
            keyring.set_password(self.SERVICE_ID, self.SYSTEM_KEY, self.system_id)
        log.debug("saved system id")
        
    def set_user_id(self, user_id):
        if(user_id):
            self.user_id = str(user_id)
            keyring.set_password(self.SERVICE_ID, self.USER_KEY, self.user_id)
        log.debug("saved user id")
        
    def init(self):
        if(self.afg and not self.panel_id):
            json = self.authenticated_json('https://www.alarm.com/web/api/identities')
            if json:
                user_id = json['data'][0]['id']
                system_id = json['data'][0]['relationships']['selectedSystem']['data']['id']
                log.debug(str(user_id)+", "+str(system_id))
                self.set_user_id(user_id)
                self.set_system_id(system_id)
                json = self.authenticated_json('https://www.alarm.com/web/api/systems/systems/'+self.system_id)
                if json:
                    panel_id = json['data']['relationships']['partitions']['data'][0]['id']
                    self.set_panel_id(panel_id)
            
    def login(self):
        response = None
        if(self.username and self.password):
            params = {
                '__PREVIOUSPAGE' : '',
			  	'__VIEWSTATE' : '',
			  	'__VIEWSTATEGENERATOR' : '',
			  	'__EVENTVALIDATION' : '',
			  	'IsFromNewSite' : '1',
			  	'JavaScriptTest' :  '1',
			  	'ctl00$ContentPlaceHolder1$loginform$hidLoginID' : '',
				'ctl00$ContentPlaceHolder1$loginform$txtUserName': self.username,
			  	'txtPassword' : self.password,
			  	'ctl00$ContentPlaceHolder1$loginform$signInButton': 'Login'
            }
            response = self.browser.request("https://www.alarm.com/login.aspx")
            if(200 == response.status_code):
                vars = {
                    '__PREVIOUSPAGE' : '',
                    '__VIEWSTATE' : '',
                    '__VIEWSTATEGENERATOR' : '',
                    '__EVENTVALIDATION' : ''
                }            
                vars = self.browser.extract_vars(response, vars)
                params = {**params, **vars}
                response = self.browser.request("https://www.alarm.com/web/Default.aspx", data=params, method='POST', headers={'Referer':'https://alarm.com/login.aspx'})
                if(200 == response.status_code):
                    self.update_state()
        return response and response.url == "https://www.alarm.com/web/system/"
    
    def authenticated_json(self, url, **kwargs):
        result = None
        authenticated =  self.last_request and (time() - self.last_request) < self.SESSION_TIMEOUT
        if(not authenticated):
            authenticated = self.login()
        if(authenticated):
            json_headers = {'Accept': 'application/vnd.api+json', 'AjaxRequestUniqueKey': self.afg, 'Referer': 'https://www.alarm.com/web/system/'}
            headers = {}
            if 'headers' in kwargs and kwargs['headers']:
                headers = kwargs['headers']
            headers = {**headers, **json_headers}
            kwargs['headers'] = headers
            response = self.browser.request(url, **kwargs)
            if(200 == response.status_code):
                result = response.json()
                self.last_request = time()
        return result
    
    def command(self, command, flags={}):
        default_flags = {'silent': True, 'bypass': False, 'nodelay': False}
        flags = {**default_flags, **flags}
        states = self.STATES
        result = None
        if(not self.afg):
            self.login()
        if(not self.panel_id):
            self.init()
        url_base = 'https://www.alarm.com/web/api/devices/partitions/'+self.panel_id
        commands = {
            states[0]:  {'method': 'POST', 'urlext': '/'+states[0], 'resultfunc': lambda x: bool(x), 'json': {'statePollOnly': False}},
            states[1]: {'method': 'POST', 'urlext': '/'+states[1], 'resultfunc': lambda x: bool(x), 'json': {'silentArming': flags['silent'], 'forceBypass': flags['bypass'], 'noEntryDelay': flags['nodelay'], 'statePollOnly': False}},
            states[2]: {'method': 'POST', 'urlext': '/'+states[2], 'resultfunc': lambda x: bool(x), 'json': {'silentArming': flags['silent'], 'forceBypass': flags['bypass'], 'noEntryDelay': flags['nodelay'], 'statePollOnly': False}},
            'refresh': {'method': 'GET', 'urlext': '', 'resultfunc': lambda x: states[int(x['data']['attributes']['state'])-1], 'json': None}
        }
        args = {'method': commands[command]['method'], 'json': commands[command]['json']}
        json = self.authenticated_json(url_base+commands[command]['urlext'], **(args))
        if json:
            result = commands[command]['resultfunc'](json)
            self.update_state()
        return result
    
    def arm_stay(self, flags={}):
        return self.command('armStay', flags)

    def arm_away(self, flags={}):
        return self.command('armAway', flags)

    def disarm(self):
        return self.command('disarm')

    def update(self):
        return self.command('refresh')

