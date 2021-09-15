#!/usr/bin/python
# -*- coding: UTF-8 -*-

import netmsg_pb2
import hall_pb2

def on_message(message):
    print("recv message")
    print(message)
    nm = netmsg_pb2.netmsg()
    nm.ParseFromString(message)
    ret = nm.name.split('.', 1)
    if ret[1] == 'response_game_type_list':
        hallmsg = hall_pb2.response_game_type_list()
        hallmsg.ParseFromString(nm.payload)
        print(hallmsg.game_type_list)
    elif ret[1] == 'response_game_kind_list':
        hallmsg = hall_pb2.response_game_kind_list()
        hallmsg.ParseFromString(nm.payload)
        print(hallmsg.game_kind_list)

def send(param):
    if param == 'test':
        return send_test()
    elif param == 'reqlist':
        return send_req_game_list()

def send_test():
    head = netmsg_pb2.netmsg()
    head.name = "hall.RequestTest"
    pack = hall_pb2.RequestTest()
    pack.req = "python send req"
    head.payload = pack.SerializeToString()
    head.sessionid = 7004
    data = head.SerializeToString()
    print('hall', data)
    return data

def send_req_game_list():
    head = netmsg_pb2.netmsg()
    head.name = "hall.request_game_list"
    pack = hall_pb2.request_game_list()
    head.payload = pack.SerializeToString()
    head.sessionid = 7004
    data = head.SerializeToString()
    print('hall req list', data)
    return data