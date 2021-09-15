#!/usr/bin/python
# -*- coding: UTF-8 -*-

import sys
import threading
import time
import websocket

import netmsg_pb2
import hall_pb2
import c_hall

class WebSocketClient(threading.Thread):

    def __init__(self, url):
        self.url = url
        self.first = True
        threading.Thread.__init__(self)

    def run(self):

        # Running the run_forever() in a seperate thread.
        websocket.enableTrace(True)
        self.ws = websocket.WebSocketApp(self.url,
                                         on_message = self.on_message,
                                         on_error = self.on_error,
                                         on_close = self.on_close)
        self.ws.on_open = self.on_open
        self.ws.run_forever()

    def send(self, data):

        # Wait till websocket is connected.
        while not self.ws.sock.connected:
            time.sleep(0.25)

        self.ws.send(data, opcode=websocket.ABNF.OPCODE_BINARY)

    def stop(self):
        print('Stopping the websocket...')
        self.ws.keep_running = False
        self.ws.close()

    def on_message(self, message):
        #print('Received data...', message)
        #print('on_message', message)
        msg_cb(message)
        
    def on_error(self, error):
        print('Received error...')
        print(error)

    def on_close(self):
        print('Closed the connection...')

    def on_open(self):
        print('Opened the connection...')
        send_auth()

wsClient = WebSocketClient("ws://localhost:8080")

def send_auth():
    head = netmsg_pb2.netmsg()
    head.name = "hall.RequestTest"
    pack = hall_pb2.RequestTest()
    pack.req = "python send req"
    head.payload = pack.SerializeToString()
    head.sessionid = 7004
    data = head.SerializeToString()
    wsClient.send(data)

def send_test():
    head = netmsg_pb2.netmsg()
    head.name = "hall.RequestTest"
    pack = hall_pb2.RequestTest()
    pack.req = "python send req"
    head.payload = pack.SerializeToString()
    head.sessionid = 7004
    data = head.SerializeToString()
    print("-------------1--------")
    print(data)
    wsClient.send(data)

auth = False

def msg_cb(message):
    global auth
    if auth:
        nm = netmsg_pb2.netmsg()
        nm.ParseFromString(message)
        ret = nm.name.split('.', 1)
        if ret[0] == 'hall':
            c_hall.on_message(message)
    else:
        auth = True

if __name__ =="__main__":

    wsClient.start()

    #send_test()
    while True:
        line = sys.stdin.readline().strip()
        ret = line.split(':', 1)
        if ret[0] == 'hall':
            data = c_hall.send(ret[1])
            wsClient.send(data)
        elif ret[0] == 'game':
            pass

        if line == 'quit':
            break

    wsClient.join()
    