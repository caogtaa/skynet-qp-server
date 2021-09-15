
¬J

hall.protohall"4
request_userinfo
userid (
password (	"[
club_info_item
clubid (
	club_name (	
member_count (
identity ("È
response_userinfo
userid (
gameid (
faceid (
gender (
nickname (	
password (	
mobilephone (	
alipay_name (	
alipay_account	 (	
bankcard_id
 (	
bankcard_name (	
	vip_level (
	signature (	
head_img_url (	
score (

bank_score (
recharge_score ('
	club_info (2.hall.club_info_item
selected_clubid (
lock_kindid (
lock_roomid ("*
response_userinfo_failed
reason (	"<
notify_update_userscore
score (

bank_score ("
request_game_list">
	game_type
sortid (
typeid (
	type_name (	"B
response_game_type_list'
game_type_list (2.hall.game_type"N
	game_kind
typeid (
sortid (
kindid (
	kind_name (	"B
response_game_kind_list'
game_kind_list (2.hall.game_kind"j
	game_room
	sessionid (
kindid (
sortid (
min_enter_score. (
	room_name (	"B
response_game_room_list'
game_room_list (2.hall.game_room"O
request_bank_save_score
userid (
password (	

save_score ("M
request_bank_get_score
userid (
password (	
	get_score ("b
reponse_bank_result
result_code (

user_score (

bank_score (
reason (	"I
request_log_change_score
userid (
password (	
day ("§
log_change_score_item
source_score (
change_score (

id (
change_type (
change_reason (	
change_origin (	
change_date (	"F
reponse_log_change_score*
items (2.hall.log_change_score_item",
request_config_shop_exchange
type ("=
response_config_shop_exchange
content (	
ext (	">
response_operate_result
result_code (
reason (	"o
request_accountup
userid (
password (	
phone_number (	
code (	
new_password (	"u
request_modify_password
userid (
password (	
new_password (	
phone_number (	
code (	"Z
request_bind_phone
userid (
password (	
phone_number (	
code (	"d
request_bind_alipay
userid (
password (	
alipay_account (	
alipay_name (	"|
request_bind_bankcard
userid (
password (	
bankcard_id (	
bankcard_name (	
bankcard_addr (	"Q
request_exchange
userid (
password (	
type (
score ("R
reponse_exchange_result
result_code (

bank_score (
reason (	"a
request_exchange_record
userid (
password (	

start_date (	
end_date (	"‡
exchange_record_item

id (
score (
revenue (
account (	
state (
reason (	
insert_date (	"K
reponse_exchange_record_result)
items (2.hall.exchange_record_item"a
request_recharge_record
userid (
password (	

start_date (	
end_date (	"†
recharge_record_item
insert_date (	
order_no (	
channel (	

pay_amount (
real_amount (
state ("K
reponse_recharge_record_result)
items (2.hall.recharge_record_item"W
request_user_message_deal
userid (
password (	

id (
deal ("8
request_user_message
userid (
password (	"d
user_message_item

id (
title (	
message (	
readed (
insert_date (	"=
notify_user_message&
items (2.hall.user_message_item"a
request_team_create_club
userid (
password (	
clubname (	
	join_auth ("i
response_team_create_club
result_code (
reason (	'
	club_info (2.hall.club_info_item"V
request_team_search_club
userid (
password (	
club_invite_code (	"i
response_team_search_club
result_code (
reason (	'
	club_info (2.hall.club_info_item"T
request_team_join_club
userid (
password (	
club_invite_code (	"g
response_team_join_club
result_code (
reason (	'
	club_info (2.hall.club_info_item"L
request_team_change_club
userid (
password (	
clubid ("P
response_team_change_club
result_code (
reason (	
clubid ("L
request_team_parent_info
userid (
password (	
clubid ("¤
response_team_parent_info
gameid (
nickname (	
head_img_url (	
invited_code (
	club_name (	
notice (	

wx (	

qq (	"G
request_team_myinfo
userid (
password (	
clubid ("´
response_team_myinfo
gameid (
nickname (	
head_img_url (	
invited_code (	
share_ratio (
notice (	

wx (	

qq (	
	club_name	 (	"M
request_team_members_info
userid (
password (	
clubid ("Ú
team_member_item
userid (
gameid (
nickname (	
head_img_url (	
parent_gameid (
last_login_date (	
share_ratio (
today_total_performance ("
yestoday_total_performance	 (
today_new_members_count
 ("
yestoday_new_members_count (
direct_members_count (
	join_date (	"…
response_team_members_info
share_ratio (
auto_be_partner ( 
auto_partner_share_ratio (4
direct_partner_items (2.hall.team_member_item3
direct_member_items (2.hall.team_member_item,
member_items (2.hall.team_member_item"[
request_team_report_info
userid (
password (	
clubid (
month ("Ô
team_report_item

id (
create_date (	
performance (
share_ratio (

commission (
partner_commission ("
direct_members_performance (!
direct_partner_commission ("¤
response_team_report_info
today_total_performance (
month_total_performance (
month_total_commission (%
items (2.hall.team_report_item"l
 request_team_partner_member_info
userid (
password (	
clubid (
partner_userid ("R
team_partner_member_item
gameid (
nickname (	
head_img_url (	"R
!response_team_partner_member_info-
items (2.hall.team_partner_member_item"_
request_team_report_member_info
userid (
password (	
clubid (

id ("˜
team_report_member_item
gameid (
nickname (	
partner (
date (	
performance (
share_ratio (

commission ("P
 response_team_report_member_info,
items (2.hall.team_report_member_item"`
 request_team_report_partner_info
userid (
password (	
clubid (

id ("ˆ
team_report_partner_item
gameid (
nickname (	
date (	
performance (
share_ratio (

commission ("R
!response_team_report_partner_info-
items (2.hall.team_report_partner_item"L
request_team_spread_info
userid (
password (	
clubid ("W
team_invited_member_item
new_members_count ( 
new_direct_members_count ("€
response_team_spread_info
invited_code (	8
new_members_item (2.hall.team_invited_member_item
invite_urls (	"v
request_team_transfer
userid (
password (	
clubid (
dest_userid (
transfer_score ("=
response_team_transfer
result_code (
reason (	"\
request_team_edit_notice
userid (
password (	
clubid (
notice (	"@
response_team_edit_notice
result_code (
reason (	"b
request_team_edit_card
userid (
password (	
clubid (

wx (	

qq (	">
response_team_edit_card
result_code (
reason (	"M
request_team_log_transfer
userid (
password (	
clubid ("›
team_log_transfer_item

id (
insert_date (	
nickname (	
gameid (
transfer_score (
state (
expired_seconds ("I
response_team_log_transfer+
items (2.hall.team_log_transfer_item"\
request_team_transfer_cancel
userid (
password (	
clubid (

id ("P
response_team_transfer_cancel
result_code (
reason (	

id ("‹
request_team_auto_be_partner
userid (
password (	
clubid (
auto_be_partner ( 
auto_partner_share_ratio ("D
response_team_auto_be_partner
result_code (
reason (	"u
request_team_be_partner
userid (
password (	
clubid (
dest_userid (
share_ratio ("?
response_team_be_partner
result_code (
reason (	"…
$request_team_set_partner_share_ratio
userid (
password (	
clubid (
partner_userid (
share_ratio ("L
%response_team_set_partner_share_ratio
result_code (
reason (	"h
request_team_game_records
userid (
password (	
clubid (
type (
day ("–
team_game_record_item
drawid (
insert_date (	
wanfa (	
gameid (
change_score (
revenue (

commission ("H
response_team_game_records*
items (2.hall.team_game_record_item"c
request_team_game_record_detail
userid (
password (	
clubid (
drawid ("j
team_game_record_detail_item
gamelog (	
start_score (
change_score (
gameid ("e
 response_team_game_record_detail
kindid (1
items (2".hall.team_game_record_detail_item