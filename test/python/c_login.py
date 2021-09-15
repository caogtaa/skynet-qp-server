#!/usr/bin/python
# -*- coding: UTF-8 -*-

import socket               # 导入 socket 模块
import base64
import random
import string
import pyDH 
 
HOST = '127.0.0.1'
PORT = 8081

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))

def unpack_line(text):
    pos = text.find('\n')
    if pos >= 0:
        return text[0 : pos - 1], text[pos + 1 :]
    return None, text

last = ""
def try_recv(l):
    global last
    result, last = unpack_line(l)
    if result:
        return result, last

    r = s.recv(8192)
    ret = bytes.decode(r)
    if ret == "":
        return "server closed", last
    
    return unpack_line(last + ret)

def read_line():
    while True:
        global last
        result, last = try_recv(last)
        if result:
            return result

def write_line(text):
    s.send(str.encode(text + "\n"))

def randomkey():
    return ''.join(random.sample(string.ascii_letters + string.digits, 8))

def try_login():
    write_line('LS login')
    challenge = base64.b64decode(read_line())
    print("challenge:" + challenge)
    clientkey = randomkey()
    print("clientkey:" + clientkey)
    d1 = pyDH.DiffieHellman()
    write_line(base64.b64encode(d1.gen_shared_key(clientkey)))
    write_line