
DROP TABLE log_team_day_report1;
DROP TABLE log_team_transfer1;
DROP TABLE user_team_bind_info1;
DROP TABLE user_team_info1;

UPDATE config_club_invite_code SET clubid = 0, userid=0;
UPDATE user_account_info SET selected_clubid = 0, clubids='';

DELETE FROM club_info;
