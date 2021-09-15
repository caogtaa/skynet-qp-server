#!/bin/bash

rm -rf ../test/python/netmsg_pb2.py
./protoc --python_out=../test/python netmsg.proto

rm -rf ../test/python/hall_pb2.py
./protoc --python_out=../test/python hall.proto