/*
 Navicat Premium Data Transfer

 Source Server         : jlb-mysql
 Source Server Type    : MySQL
 Source Server Version : 50733
 Source Host           : :3306
 Source Schema         : gamedb

 Target Server Type    : MySQL
 Target Server Version : 50733
 File Encoding         : 65001

 Date: 15/09/2021 19:34:35
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for club_info
-- ----------------------------
DROP TABLE IF EXISTS `club_info`;
CREATE TABLE `club_info`  (
  `clubid` int(11) NOT NULL,
  `creator_userid` int(10) UNSIGNED NOT NULL COMMENT '俱乐部创建者',
  `name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '俱乐部名字',
  `member_count` int(11) NOT NULL DEFAULT 0 COMMENT '会员数量',
  `create_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`clubid`) USING BTREE,
  UNIQUE INDEX `clubid_UNIQUE`(`clubid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '俱乐部信息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_change_score
-- ----------------------------
DROP TABLE IF EXISTS `config_change_score`;
CREATE TABLE `config_change_score`  (
  `c_name` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `c_value` int(11) NOT NULL,
  `c_string` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '配置字符',
  PRIMARY KEY (`c_name`) USING BTREE,
  UNIQUE INDEX `c_value_UNIQUE`(`c_value`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '账户变动记录的对应类型和描述' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_club_invite_code
-- ----------------------------
DROP TABLE IF EXISTS `config_club_invite_code`;
CREATE TABLE `config_club_invite_code`  (
  `id` int(11) NOT NULL,
  `invite_code` int(11) NOT NULL,
  `clubid` int(11) NOT NULL DEFAULT 0,
  `userid` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`, `clubid`) USING BTREE,
  UNIQUE INDEX `gameid_UNIQUE`(`invite_code`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '预先生成一批俱乐部邀请码' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_game_kind_list
-- ----------------------------
DROP TABLE IF EXISTS `config_game_kind_list`;
CREATE TABLE `config_game_kind_list`  (
  `kindid` int(10) UNSIGNED NOT NULL COMMENT '游戏id',
  `typeid` int(10) UNSIGNED NOT NULL COMMENT '游戏所属类型',
  `sortid` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序号',
  `kind_name` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '游戏名字',
  `disabled` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT '是否禁用',
  PRIMARY KEY (`kindid`) USING BTREE,
  UNIQUE INDEX `kindid_UNIQUE`(`kindid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '游戏种类列表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_game_robot_rule
-- ----------------------------
DROP TABLE IF EXISTS `config_game_robot_rule`;
CREATE TABLE `config_game_robot_rule`  (
  `id` int(10) UNSIGNED NOT NULL,
  `kindid` int(10) UNSIGNED NOT NULL,
  `roomid` int(10) UNSIGNED NOT NULL,
  `room_desc` varchar(32) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL DEFAULT '',
  `min_take_score` bigint(20) NOT NULL COMMENT '最小携带分数',
  `max_take_score` bigint(20) NOT NULL COMMENT '最大携带分数',
  `min_play_time` int(11) NOT NULL COMMENT '最小游戏时间',
  `max_play_time` int(11) NOT NULL COMMENT '最大游戏时间',
  `min_play_draw` int(11) NOT NULL COMMENT '最小局数',
  `max_play_draw` int(11) NOT NULL COMMENT '最大局数',
  `min_robot_count` int(11) NOT NULL COMMENT '最小机器人数量',
  `max_robot_count` int(11) NOT NULL COMMENT '最大机器人数量',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE,
  UNIQUE INDEX `roomid_UNIQUE`(`roomid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '游戏机器人配置' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_game_type_list
-- ----------------------------
DROP TABLE IF EXISTS `config_game_type_list`;
CREATE TABLE `config_game_type_list`  (
  `typeid` int(10) UNSIGNED NOT NULL,
  `sortid` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序号',
  `type_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '类型名',
  `disabled` tinyint(4) UNSIGNED NOT NULL DEFAULT 0 COMMENT '是否禁用',
  PRIMARY KEY (`typeid`) USING BTREE,
  UNIQUE INDEX `typeid_UNIQUE`(`typeid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '游戏类型列表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_gameids
-- ----------------------------
DROP TABLE IF EXISTS `config_gameids`;
CREATE TABLE `config_gameids`  (
  `userid` int(11) NOT NULL,
  `gameid` int(11) NOT NULL,
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `gameid_UNIQUE`(`gameid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '预先生成一批游戏ID' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_global
-- ----------------------------
DROP TABLE IF EXISTS `config_global`;
CREATE TABLE `config_global`  (
  `c_name` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `c_value` int(11) NOT NULL,
  `c_string` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '配置字符',
  `c_desc` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '描述',
  PRIMARY KEY (`c_name`) USING BTREE,
  UNIQUE INDEX `c_name_UNIQUE`(`c_name`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '全局配置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for config_shop_exchange
-- ----------------------------
DROP TABLE IF EXISTS `config_shop_exchange`;
CREATE TABLE `config_shop_exchange`  (
  `type` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `content` json NOT NULL,
  PRIMARY KEY (`type`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_change_score
-- ----------------------------
DROP TABLE IF EXISTS `log_change_score`;
CREATE TABLE `log_change_score`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(10) UNSIGNED NOT NULL,
  `kindid` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `roomid` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `source_score` bigint(20) NOT NULL COMMENT '变更前的分数',
  `change_score` bigint(20) NOT NULL COMMENT '改变的分数',
  `source_bank_score` bigint(20) NOT NULL COMMENT '变更前的银行分数',
  `change_bank_score` bigint(20) NOT NULL COMMENT '变更的银行分数',
  `change_type` int(11) NOT NULL DEFAULT 0 COMMENT '变更类型',
  `change_reason` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '变更原因',
  `change_origin` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '变更来源 比如游戏是局号 充值是订单号',
  `change_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '分数变更日志' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_exchange
-- ----------------------------
DROP TABLE IF EXISTS `log_exchange`;
CREATE TABLE `log_exchange`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(11) NOT NULL,
  `score` bigint(20) NOT NULL,
  `revenue` bigint(20) NOT NULL,
  `type` tinyint(4) NOT NULL COMMENT '0 银行卡 1支付宝 2USDT',
  `account` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '银行卡或支付宝帐号',
  `account_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL COMMENT '银行卡或支付宝帐号名字',
  `state` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0 未处理 1 已经处理 2 处理失败 比如帐号不对',
  `reason` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '失败原因',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '处理时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_game_record
-- ----------------------------
DROP TABLE IF EXISTS `log_game_record`;
CREATE TABLE `log_game_record`  (
  `drawid` bigint(20) NOT NULL COMMENT '牌局编号',
  `kindid` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '游戏ID',
  `roomid` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '房间ID',
  `tableid` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '桌子号',
  `wanfa` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '玩法',
  `user_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '用户数',
  `robot_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '机器人数',
  `change_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '平台输赢',
  `revenue` bigint(20) NOT NULL DEFAULT 0 COMMENT '平台税收',
  `game_start_date` datetime NOT NULL COMMENT '游戏开始时间',
  `game_end_date` datetime NOT NULL COMMENT '游戏结束时间',
  PRIMARY KEY (`drawid`) USING BTREE,
  UNIQUE INDEX `drawid_UNIQUE`(`drawid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '游戏记录主表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_game_record_detail
-- ----------------------------
DROP TABLE IF EXISTS `log_game_record_detail`;
CREATE TABLE `log_game_record_detail`  (
  `id` int(11) NOT NULL,
  `drawid` bigint(20) NOT NULL COMMENT '局号',
  `userid` int(10) UNSIGNED NOT NULL COMMENT '用户ID',
  `kindid` int(10) UNSIGNED NOT NULL COMMENT '游戏ID',
  `roomid` int(10) UNSIGNED NOT NULL COMMENT '房间ID',
  `tableid` int(10) UNSIGNED NOT NULL COMMENT '桌子号',
  `chairid` int(10) UNSIGNED NOT NULL COMMENT '椅子号',
  `wanfa` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '玩法',
  `change_score` bigint(20) NOT NULL COMMENT '输赢',
  `revenue` bigint(20) NOT NULL COMMENT '税收抽水',
  `start_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '初始分数',
  `end_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '结束分数',
  `start_bank_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '初始银行分数',
  `end_bank_socre` bigint(20) NOT NULL DEFAULT 0 COMMENT '结束银行分数',
  `play_time` int(10) NOT NULL DEFAULT 0 COMMENT '游戏时长(S)',
  `gamelog` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '游戏日志',
  `performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '业绩',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '插入时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '游戏记录细节表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_recharge
-- ----------------------------
DROP TABLE IF EXISTS `log_recharge`;
CREATE TABLE `log_recharge`  (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL,
  `trade_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '交易订单号 一般是第3方提供',
  `order_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '订单号 一般是自己生成',
  `pay_amount` bigint(20) NOT NULL COMMENT '支付金额',
  `real_amount` bigint(20) NOT NULL COMMENT '到账金额',
  `subject` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '支付标题',
  `channel` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '支付通道名',
  `state` tinyint(4) NOT NULL DEFAULT 0 COMMENT '支付状态 0 待支付 1支付成功 2支付超时',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '支付成功更新',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_team_day_report
-- ----------------------------
DROP TABLE IF EXISTS `log_team_day_report`;
CREATE TABLE `log_team_day_report`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(10) UNSIGNED NOT NULL,
  `performance` bigint(20) NOT NULL COMMENT '当天总业绩',
  `share_ratio` bigint(20) NOT NULL COMMENT '分成比例',
  `commission` bigint(20) NOT NULL COMMENT '本人佣金',
  `partner_commission` bigint(20) NOT NULL COMMENT '合伙人收佣金  包括直接和间接',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属会员用户',
  `direct_members_performance` bigint(20) NOT NULL COMMENT '直属会员业绩',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属合伙人用户',
  `direct_partner_commission` bigint(20) NOT NULL COMMENT '直属合伙人佣金',
  `new_members_count` int(11) NOT NULL COMMENT '团队新增成员数量  包括直接和间接',
  `new_direct_members_count` int(11) NOT NULL COMMENT '新增直属会员数',
  `create_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队每天的报表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_team_day_report1
-- ----------------------------
DROP TABLE IF EXISTS `log_team_day_report1`;
CREATE TABLE `log_team_day_report1`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(10) UNSIGNED NOT NULL,
  `performance` bigint(20) NOT NULL COMMENT '当天总业绩',
  `share_ratio` bigint(20) NOT NULL COMMENT '分成比例',
  `commission` bigint(20) NOT NULL COMMENT '本人佣金',
  `partner_commission` bigint(20) NOT NULL COMMENT '合伙人收佣金  包括直接和间接',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属会员用户',
  `direct_members_performance` bigint(20) NOT NULL COMMENT '直属会员业绩',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属合伙人用户',
  `direct_partner_commission` bigint(20) NOT NULL COMMENT '直属合伙人佣金',
  `new_members_count` int(11) NOT NULL COMMENT '团队新增成员数量  包括直接和间接',
  `new_direct_members_count` int(11) NOT NULL COMMENT '新增直属会员数',
  `create_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队每天的报表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for log_team_day_report2
-- ----------------------------
DROP TABLE IF EXISTS `log_team_day_report2`;
CREATE TABLE `log_team_day_report2`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(10) UNSIGNED NOT NULL,
  `performance` bigint(20) NOT NULL COMMENT '当天总业绩',
  `share_ratio` bigint(20) NOT NULL COMMENT '分成比例',
  `commission` bigint(20) NOT NULL COMMENT '本人佣金',
  `partner_commission` bigint(20) NOT NULL COMMENT '合伙人收佣金  包括直接和间接',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属会员用户',
  `direct_members_performance` bigint(20) NOT NULL COMMENT '直属会员业绩',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属合伙人用户',
  `direct_partner_commission` bigint(20) NOT NULL COMMENT '直属合伙人佣金',
  `new_members_count` int(11) NOT NULL COMMENT '团队新增成员数量  包括直接和间接',
  `new_direct_members_count` int(11) NOT NULL COMMENT '新增直属会员数',
  `create_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队每天的报表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for log_team_day_report3
-- ----------------------------
DROP TABLE IF EXISTS `log_team_day_report3`;
CREATE TABLE `log_team_day_report3`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(10) UNSIGNED NOT NULL,
  `performance` bigint(20) NOT NULL COMMENT '当天总业绩',
  `share_ratio` bigint(20) NOT NULL COMMENT '分成比例',
  `commission` bigint(20) NOT NULL COMMENT '本人佣金',
  `partner_commission` bigint(20) NOT NULL COMMENT '合伙人收佣金  包括直接和间接',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属会员用户',
  `direct_members_performance` bigint(20) NOT NULL COMMENT '直属会员业绩',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属合伙人用户',
  `direct_partner_commission` bigint(20) NOT NULL COMMENT '直属合伙人佣金',
  `new_members_count` int(11) NOT NULL COMMENT '团队新增成员数量  包括直接和间接',
  `new_direct_members_count` int(11) NOT NULL COMMENT '新增直属会员数',
  `create_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队每天的报表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for log_team_transfer
-- ----------------------------
DROP TABLE IF EXISTS `log_team_transfer`;
CREATE TABLE `log_team_transfer`  (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL COMMENT '转账用户ID',
  `dest_userid` int(11) NOT NULL COMMENT '目标用户ID',
  `dest_gameid` int(11) NOT NULL COMMENT '目标游戏ID',
  `dest_nickname` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '目标昵称',
  `transfer_score` bigint(20) NOT NULL COMMENT '转账金额',
  `state` tinyint(4) NOT NULL COMMENT '0 等待确认 1 转账成功 2 转账撤回',
  `insert_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for log_team_transfer1
-- ----------------------------
DROP TABLE IF EXISTS `log_team_transfer1`;
CREATE TABLE `log_team_transfer1`  (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL COMMENT '转账用户ID',
  `dest_userid` int(11) NOT NULL COMMENT '目标用户ID',
  `dest_gameid` int(11) NOT NULL COMMENT '目标游戏ID',
  `dest_nickname` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '目标昵称',
  `transfer_score` bigint(20) NOT NULL COMMENT '转账金额',
  `state` tinyint(4) NOT NULL COMMENT '0 等待确认 1 转账成功 2 转账撤回',
  `insert_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for log_team_transfer2
-- ----------------------------
DROP TABLE IF EXISTS `log_team_transfer2`;
CREATE TABLE `log_team_transfer2`  (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL COMMENT '转账用户ID',
  `dest_userid` int(11) NOT NULL COMMENT '目标用户ID',
  `dest_gameid` int(11) NOT NULL COMMENT '目标游戏ID',
  `dest_nickname` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '目标昵称',
  `transfer_score` bigint(20) NOT NULL COMMENT '转账金额',
  `state` tinyint(4) NOT NULL COMMENT '0 等待确认 1 转账成功 2 转账撤回',
  `insert_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for log_team_transfer3
-- ----------------------------
DROP TABLE IF EXISTS `log_team_transfer3`;
CREATE TABLE `log_team_transfer3`  (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL COMMENT '转账用户ID',
  `dest_userid` int(11) NOT NULL COMMENT '目标用户ID',
  `dest_gameid` int(11) NOT NULL COMMENT '目标游戏ID',
  `dest_nickname` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '目标昵称',
  `transfer_score` bigint(20) NOT NULL COMMENT '转账金额',
  `state` tinyint(4) NOT NULL COMMENT '0 等待确认 1 转账成功 2 转账撤回',
  `insert_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for log_user_inout
-- ----------------------------
DROP TABLE IF EXISTS `log_user_inout`;
CREATE TABLE `log_user_inout`  (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` int(10) UNSIGNED NOT NULL,
  `kindid` int(10) UNSIGNED NOT NULL,
  `roomid` int(10) UNSIGNED NOT NULL,
  `enter_score` bigint(20) NOT NULL COMMENT '进入分数',
  `enter_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '进入时间',
  `enter_ip` varchar(21) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL,
  `enter_uuid` varchar(32) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL,
  `leave_date` datetime NULL DEFAULT NULL COMMENT '离开时间',
  `leave_ip` varchar(21) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL,
  `leave_uuid` varchar(32) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL,
  `change_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '变更的分数',
  `revenue` bigint(20) NOT NULL DEFAULT 0,
  `play_time` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '游戏时长',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '用户进出日志' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_account_info
-- ----------------------------
DROP TABLE IF EXISTS `user_account_info`;
CREATE TABLE `user_account_info`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `gameid` int(11) NOT NULL,
  `username` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `nickname` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '昵称',
  `password` char(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '登陆密码',
  `bank_password` char(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '银行密码',
  `faceid` smallint(6) NOT NULL DEFAULT 0 COMMENT '头像ID',
  `head_img_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '头像地址',
  `gender` tinyint(4) NOT NULL DEFAULT 0,
  `signature` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '个性签名',
  `real_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '真实名字',
  `email` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `alipay_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '支付宝名字',
  `alipay_account` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '支付宝帐号',
  `bankcard_id` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '银行卡号',
  `bankcard_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `bankcard_addr` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '银行卡开户行地址',
  `mobilephone` varchar(11) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机号码',
  `vip_level` tinyint(4) NOT NULL DEFAULT 0 COMMENT 'VIP等级',
  `master_level` tinyint(4) NOT NULL DEFAULT 0 COMMENT '管理员等级',
  `disabled` tinyint(4) NOT NULL DEFAULT 0 COMMENT '账户禁用 0 不禁用 其他数字表示禁用原因',
  `reactivate_date` datetime NOT NULL DEFAULT '1900-01-01 00:00:00' COMMENT '禁用后重新激活日期',
  `is_robot` tinyint(4) NOT NULL DEFAULT 0 COMMENT '是否机器人',
  `last_login_ip` varchar(21) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '-' COMMENT '上次登陆IP',
  `last_login_date` datetime NOT NULL DEFAULT '1900-01-01 00:00:00' COMMENT '上次登陆日期',
  `last_login_device` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '上次登陆设备',
  `last_login_uuid` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '上次登陆机器码',
  `register_ip` varchar(21) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '注册IP',
  `register_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册日期',
  `register_device` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '注册设备',
  `register_uuid` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '注册机器码',
  `remarks` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '‘’' COMMENT '备注',
  `channelid` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '渠道',
  `type` int(11) NOT NULL DEFAULT 0 COMMENT '0正常帐号 1机器人 2可以创建俱乐部 3渠道用户',
  `clubids` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '已经加入的所有俱乐部ID 逗号隔开',
  `selected_clubid` int(11) NOT NULL DEFAULT 0 COMMENT '当前俱乐部id',
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `user_id_UNIQUE`(`userid`) USING BTREE,
  UNIQUE INDEX `game_id_UNIQUE`(`gameid`) USING BTREE,
  UNIQUE INDEX `user_name_UNIQUE`(`username`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '用户账号的基本信息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_game_info
-- ----------------------------
DROP TABLE IF EXISTS `user_game_info`;
CREATE TABLE `user_game_info`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `score` bigint(20) NOT NULL DEFAULT 0,
  `bank_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '银行分数',
  `win_count` int(11) NOT NULL DEFAULT 0 COMMENT '赢局数目',
  `lost_count` int(11) NOT NULL DEFAULT 0 COMMENT '输局数目',
  `draw_count` int(11) NOT NULL DEFAULT 0 COMMENT '和局数目',
  `revenue` bigint(20) NOT NULL DEFAULT 0 COMMENT '系统抽水',
  `play_time` int(11) NOT NULL DEFAULT 0 COMMENT '游戏时长 秒',
  `experience` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '经验值',
  `recharge_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '总充值分数',
  `recharge_times` int(11) NOT NULL DEFAULT 0 COMMENT '总充值次数',
  `exchange_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '总兑换分数',
  `exchange_times` int(11) NOT NULL DEFAULT 0 COMMENT '总兑换次数',
  `balance_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '总输赢分数',
  `today_balance_score` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日输赢分数',
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '用户的游戏信息 包括分数,税收,局数,游戏时长,充值等等频繁变动的信息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_message
-- ----------------------------
DROP TABLE IF EXISTS `user_message`;
CREATE TABLE `user_message`  (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL,
  `title` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '邮件标题',
  `message` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '邮件内容',
  `readed` tinyint(4) NOT NULL COMMENT '0 未读 1已读取 2删除',
  `insert_date` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '所有用户的邮件' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_team_bind_info
-- ----------------------------
DROP TABLE IF EXISTS `user_team_bind_info`;
CREATE TABLE `user_team_bind_info`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `invite_code` int(11) NOT NULL COMMENT '邀请码',
  `auto_be_partner` tinyint(4) NOT NULL DEFAULT 0 COMMENT '自动成为合伙人',
  `auto_partner_share_ratio` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '自动成为合伙人的分成比例',
  `parent_userid` int(11) NOT NULL COMMENT '上级用户ID',
  `parent_gameid` int(11) NOT NULL COMMENT '上级游戏ID',
  `wx` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '微信号',
  `qq` varchar(24) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'qq号',
  `notice` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '公告',
  `parent_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有上级ID 以英文逗号隔开',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有直属成员 不包括合伙人',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '直属合伙人 ',
  `member_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '间接成员 不包括直属成员',
  `partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '合伙人 不包括直属合伙人',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队绑定信息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_team_bind_info1
-- ----------------------------
DROP TABLE IF EXISTS `user_team_bind_info1`;
CREATE TABLE `user_team_bind_info1`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `invite_code` int(11) NOT NULL COMMENT '邀请码',
  `auto_be_partner` tinyint(4) NOT NULL DEFAULT 0 COMMENT '自动成为合伙人',
  `auto_partner_share_ratio` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '自动成为合伙人的分成比例',
  `parent_userid` int(11) NOT NULL COMMENT '上级用户ID',
  `parent_gameid` int(11) NOT NULL COMMENT '上级游戏ID',
  `wx` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '微信号',
  `qq` varchar(24) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'qq号',
  `notice` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '公告',
  `parent_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有上级ID 以英文逗号隔开',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有直属成员 不包括合伙人',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '直属合伙人 ',
  `member_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '间接成员 不包括直属成员',
  `partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '合伙人 不包括直属合伙人',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队绑定信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_team_bind_info2
-- ----------------------------
DROP TABLE IF EXISTS `user_team_bind_info2`;
CREATE TABLE `user_team_bind_info2`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `invite_code` int(11) NOT NULL COMMENT '邀请码',
  `auto_be_partner` tinyint(4) NOT NULL DEFAULT 0 COMMENT '自动成为合伙人',
  `auto_partner_share_ratio` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '自动成为合伙人的分成比例',
  `parent_userid` int(11) NOT NULL COMMENT '上级用户ID',
  `parent_gameid` int(11) NOT NULL COMMENT '上级游戏ID',
  `wx` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '微信号',
  `qq` varchar(24) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'qq号',
  `notice` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '公告',
  `parent_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有上级ID 以英文逗号隔开',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有直属成员 不包括合伙人',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '直属合伙人 ',
  `member_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '间接成员 不包括直属成员',
  `partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '合伙人 不包括直属合伙人',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队绑定信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_team_bind_info3
-- ----------------------------
DROP TABLE IF EXISTS `user_team_bind_info3`;
CREATE TABLE `user_team_bind_info3`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `invite_code` int(11) NOT NULL COMMENT '邀请码',
  `auto_be_partner` tinyint(4) NOT NULL DEFAULT 0 COMMENT '自动成为合伙人',
  `auto_partner_share_ratio` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '自动成为合伙人的分成比例',
  `parent_userid` int(11) NOT NULL COMMENT '上级用户ID',
  `parent_gameid` int(11) NOT NULL COMMENT '上级游戏ID',
  `wx` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '微信号',
  `qq` varchar(24) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'qq号',
  `notice` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '公告',
  `parent_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有上级ID 以英文逗号隔开',
  `direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有直属成员 不包括合伙人',
  `direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '直属合伙人 ',
  `member_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '间接成员 不包括直属成员',
  `partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '合伙人 不包括直属合伙人',
  `insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队绑定信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_team_info
-- ----------------------------
DROP TABLE IF EXISTS `user_team_info`;
CREATE TABLE `user_team_info`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `team_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '团队成员数量包括直属和间接成员',
  `direct_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '直属成员数量',
  `share_ratio` int(11) NOT NULL DEFAULT 0 COMMENT '分成比例',
  `month_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总业绩',
  `month_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总收益',
  `today_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总业绩',
  `today_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总佣金',
  `today_new_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增会员数量   包括直接和间接',
  `today_new_direct_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增直属会员数目',
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_team_info1
-- ----------------------------
DROP TABLE IF EXISTS `user_team_info1`;
CREATE TABLE `user_team_info1`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `team_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '团队成员数量包括直属和间接成员',
  `direct_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '直属成员数量',
  `share_ratio` int(11) NOT NULL DEFAULT 0 COMMENT '分成比例',
  `month_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总业绩',
  `month_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总收益',
  `today_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总业绩',
  `today_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总佣金',
  `today_new_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增会员数量 包括直接和间接',
  `today_new_direct_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增直属会员数目',
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_team_info2
-- ----------------------------
DROP TABLE IF EXISTS `user_team_info2`;
CREATE TABLE `user_team_info2`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `team_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '团队成员数量包括直属和间接成员',
  `direct_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '直属成员数量',
  `share_ratio` int(11) NOT NULL DEFAULT 0 COMMENT '分成比例',
  `month_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总业绩',
  `month_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总收益',
  `today_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总业绩',
  `today_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总佣金',
  `today_new_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增会员数量 包括直接和间接',
  `today_new_direct_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增直属会员数目',
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_team_info3
-- ----------------------------
DROP TABLE IF EXISTS `user_team_info3`;
CREATE TABLE `user_team_info3`  (
  `userid` int(10) UNSIGNED NOT NULL,
  `team_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '团队成员数量包括直属和间接成员',
  `direct_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '直属成员数量',
  `share_ratio` int(11) NOT NULL DEFAULT 0 COMMENT '分成比例',
  `month_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总业绩',
  `month_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总收益',
  `today_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总业绩',
  `today_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总佣金',
  `today_new_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增会员数量 包括直接和间接',
  `today_new_direct_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增直属会员数目',
  PRIMARY KEY (`userid`) USING BTREE,
  UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队信息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Procedure structure for create_club
-- ----------------------------
DROP PROCEDURE IF EXISTS `create_club`;
delimiter ;;
CREATE PROCEDURE `create_club`(IN `clubid` int)
BEGIN
	SET NAMES utf8mb4;
	SET FOREIGN_KEY_CHECKS = 0;

	
	SET @tb1 = CONCAT('
	CREATE TABLE `user_team_info', clubid, "`  (
		`userid` int(10) UNSIGNED NOT NULL,
		`team_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '团队成员数量包括直属和间接成员',
		`direct_members_count` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '直属成员数量',
		`share_ratio` int(11) NOT NULL DEFAULT 0 COMMENT '分成比例',
		`month_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总业绩',
		`month_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '当月总收益',
		`today_total_performance` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总业绩',
		`today_total_commission` bigint(20) NOT NULL DEFAULT 0 COMMENT '今日总佣金',
		`today_new_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增会员数量 包括直接和间接',
		`today_new_direct_members_count` int(11) NOT NULL DEFAULT 0 COMMENT '今日新增直属会员数目',
		PRIMARY KEY (`userid`) USING BTREE,
		UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
	) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队信息' ROW_FORMAT = Dynamic;
	");
	PREPARE stmt1 FROM @tb1;
  EXECUTE stmt1;
  DEALLOCATE PREPARE stmt1;
	
	SET @tb2 = CONCAT('
	CREATE TABLE `user_team_bind_info', clubid, "`  (
		`userid` int(10) UNSIGNED NOT NULL,
		`invite_code` int(11) NOT NULL COMMENT '邀请码',
		`auto_be_partner` tinyint(4) NOT NULL DEFAULT 0 COMMENT '自动成为合伙人',
		`auto_partner_share_ratio` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT '自动成为合伙人的分成比例',
		`parent_userid` int(11) NOT NULL COMMENT '上级用户ID',
		`parent_gameid` int(11) NOT NULL COMMENT '上级游戏ID',
		`wx` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '微信号',
		`qq` varchar(24) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'qq号',
		`notice` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '公告',
		`parent_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有上级ID 以英文逗号隔开',
		`direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '所有直属成员 不包括合伙人',
		`direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '直属合伙人 ',
		`member_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '间接成员 不包括直属成员',
		`partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '合伙人 不包括直属合伙人',
		`insert_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
		PRIMARY KEY (`userid`) USING BTREE,
		UNIQUE INDEX `userid_UNIQUE`(`userid`) USING BTREE
	) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队绑定信息' ROW_FORMAT = Dynamic;
	");
	PREPARE stmt2 FROM @tb2;
  EXECUTE stmt2;
  DEALLOCATE PREPARE stmt2;
	
	SET @tb3 = CONCAT('
	CREATE TABLE `log_team_day_report', clubid, "`  (
		`id` int(10) UNSIGNED NOT NULL,
		`userid` int(10) UNSIGNED NOT NULL,
		`performance` bigint(20) NOT NULL COMMENT '当天总业绩',
		`share_ratio` bigint(20) NOT NULL COMMENT '分成比例',
		`commission` bigint(20) NOT NULL COMMENT '本人佣金',
		`partner_commission` bigint(20) NOT NULL COMMENT '合伙人收佣金  包括直接和间接',
		`direct_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属会员用户',
		`direct_members_performance` bigint(20) NOT NULL COMMENT '直属会员业绩',
		`direct_partner_userids` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '当天的直属合伙人用户',
		`direct_partner_commission` bigint(20) NOT NULL COMMENT '直属合伙人佣金',
		`new_members_count` int(11) NOT NULL COMMENT '团队新增成员数量  包括直接和间接',
		`new_direct_members_count` int(11) NOT NULL COMMENT '新增直属会员数',
		`create_date` datetime NOT NULL,
		PRIMARY KEY (`id`) USING BTREE,
		UNIQUE INDEX `id_UNIQUE`(`id`) USING BTREE
	) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci COMMENT = '团队每天的报表' ROW_FORMAT = Dynamic;
	");
	PREPARE stmt3 FROM @tb3;
  EXECUTE stmt3;
  DEALLOCATE PREPARE stmt3;
	
	SET @tb4 = CONCAT('
	CREATE TABLE `log_team_transfer', clubid, "`  (
		`id` int(11) NOT NULL,
		`userid` int(11) NOT NULL COMMENT '转账用户ID',
		`dest_userid` int(11) NOT NULL COMMENT '目标用户ID',
		`dest_gameid` int(11) NOT NULL COMMENT '目标游戏ID',
		`dest_nickname` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '目标昵称',
		`transfer_score` bigint(20) NOT NULL COMMENT '转账金额',
		`state` tinyint(4) NOT NULL COMMENT '0 等待确认 1 转账成功 2 转账撤回',
		`insert_date` datetime NOT NULL,
		PRIMARY KEY (`id`) USING BTREE
	) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;
	");
	PREPARE stmt4 FROM @tb4;
  EXECUTE stmt4;
  DEALLOCATE PREPARE stmt4;

	SET FOREIGN_KEY_CHECKS = 1;

END
;;
delimiter ;

SET FOREIGN_KEY_CHECKS = 1;
