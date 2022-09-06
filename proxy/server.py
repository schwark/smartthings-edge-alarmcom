import logging
from http.client import HTTPConnection
HTTPConnection.debuglevel = 0

logging.basicConfig(filename="/tmp/alarmcom.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.NOTSET)
log = logging.getLogger()
log.setLevel(logging.DEBUG)
requests_log = logging.getLogger("requests.packages.urllib3")
requests_log.setLevel(logging.DEBUG)
requests_log.propagate = True
ssdpy_log = logging.getLogger("ssdpy.server")
ssdpy_log.setLevel(logging.WARNING)
ssdpy_log.propagate = True


from http.server import BaseHTTPRequestHandler,HTTPServer
from socketserver import ThreadingMixIn
from ssdpy import SSDPServer
import socket
import argparse, requests
import threading

class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.0'
    supported_servers = ['www.alarm.com']
    
    def get_server(self, index):
        return self.supported_servers[index-1]
    
    def get_base_headers(self, hostname):
        return {'Host': hostname}
    
    def do_HEAD(self):
        self.do_GET(body=False)
        return
        
    def do_GET(self, body=True):
        sent = False
        try:
            empty, first, rest = self.path.split('/',2)
            hostname = self.get_server(int(first))
            url = 'https://{}{}'.format(hostname, '/'+rest)
            req_header = (self.parse_headers() | self.get_base_headers(hostname))

            log.debug("========start-get========")
            log.debug("header: %s", req_header)
            log.debug("url: %s", url)
            resp = requests.get(url, headers=req_header, allow_redirects=False)
            sent = True

            self.send_response(resp.status_code)
            self.send_resp_headers(resp)
            msg = resp.text
            if body:
                self.wfile.write(msg.encode(encoding='UTF-8',errors='strict'))
            return
        finally:
            if not sent:
                self.send_error(404, 'error trying to proxy')
            log.debug("========end-get========")

    def do_POST(self, body=True):
        sent = False
        try:
            empty, first, rest = self.path.split('/',2)
            hostname = self.get_server(int(first))
            url = 'https://{}{}'.format(hostname, '/'+rest)
            content_len = int(self.headers.get('content-length', 0))
            post_body = self.rfile.read(content_len)
            req_header = (self.parse_headers() | self.get_base_headers(hostname))

            log.debug("========start-post========")
            log.debug("header: %s", req_header)
            log.debug("url: %s", url)
            log.debug("body: %s", post_body)
            resp = requests.post(url, data=post_body, headers=req_header, allow_redirects=False)
            sent = True

            self.send_response(resp.status_code)
            self.send_resp_headers(resp)
            if body:
                self.wfile.write(resp.content)
            return
        finally:
            if not sent:
                self.send_error(404, 'error trying to proxy')
            log.debug("========end-post========")

    def parse_headers(self):
        req_header = {}
        for key in self.headers.keys():
            req_header[key] = self.headers.get(key)
        return req_header

    def send_resp_headers(self, resp):
        respheaders = resp.headers
        for key in respheaders:
            if key not in ['Content-Encoding', 'Transfer-Encoding', 'content-encoding', 'transfer-encoding', 'content-length', 'Content-Length']:
                log.debug("%s : %s", key, respheaders[key])
                self.send_header(key, respheaders[key])
        self.send_header('Content-Length', len(resp.content))
        self.end_headers()
        
class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Handle requests in a separate thread."""


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

def start_proxy():
    ip = get_ip()    
    server_address = (ip, int(args.port))
    httpd = ThreadedHTTPServer(server_address, ProxyHTTPRequestHandler)
    print('http server is running as reverse proxy at '+ip+':'+args.port)
    httpd.serve_forever()

def start_ssdp():
    ip = get_ip()    
    server = SSDPServer("uuid:de8a5619-2603-40d1-9e21-1967952d7f86", device_type="urn:SmartThingsCommunity:device:GenericProxy:1", location='http://'+get_ip()+':'+str(args.port)+'/')
    print('ssdp server is running '+ip+':'+args.port)
    server.serve_forever()
        

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", help="port for proxy",
                        default="8081")
    parser.add_argument("--nossdp", help="does not start ssdp server",
                        action="store_true")
    args = parser.parse_args()

    threads = [threading.Thread(target=start_proxy)]
    if(not args.nossdp):
        threads.append(threading.Thread(target=start_ssdp))

    for th in threads:
        th.start()
        print(f'threads {th} started')
        th.join(0.1)