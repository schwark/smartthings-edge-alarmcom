import json
import requests
import re

class Browser:    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36'})
        self.formre = re.compile(r'<input.*?name=[\'"]([^\'"]+).*?value=[\'"]([^\'"]*)', re.I)
 
    def extract_vars(self, response, vars):
        values = self.formre.findall(response.text)
        for name, value in values:
            if name in vars:
                vars[name] = value
        return vars

    def request(self, url, **kwargs):
        method = 'GET'
        if 'method' in kwargs and kwargs['method']:
            method = kwargs['method']
            del kwargs['method']
        response = self.session.request(method, url, **kwargs)
        return response