#!/bin/bash

nohup ./skynet/skynet ./config/config.db >>./log/nohup_db.log &

nohup ./skynet/skynet ./config/config.center >>./log/nohup_center.log &

nohup ./skynet/skynet ./config/config.game.niuniu >>./log/nohup_game_niuniu.log &

nohup ./skynet/skynet ./config/config.hall >>./log/nohup_hall.log &

nohup ./skynet/skynet ./config/config.gate >>./log/nohup_gate.log &

nohup ./skynet/skynet ./config/config.login >>./log/nohup_login.log &

del temp_game_robot_userinfo:roomid:6000
sadd temp_game_robot_userinfo:free 4 8 9 10 11 12 13 14 15 16 17
del game_user_locker:userid:1 game_user_locker:userid:4 game_user_locker:userid:8 game_user_locker:userid:9 game_user_locker:userid:10 game_user_locker:userid:11 game_user_locker:userid:12 game_user_locker:userid:13 game_user_locker:userid:14 game_user_locker:userid:15 game_user_locker:userid:16 game_user_locker:userid:17