<?php
/***************************************************************************
                                digests_send_now.php
                             -------------------
    begin                : Sat Oct 4 2003
    copyright            : (C) 2000 The phpBB Group
    copyright            : (C) 2005 Terrell Russell

    $Id: $

 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

// Written by Mark D. Hamill, mhamill@computer.org
// This software was originally designed to work with phpBB Version 2.0.8

// modified by Terrell Russell, punbb@terrellrussell.com
// This file has been modified to work with punBB 1.2.4

// ----------------------------------------- ATTENTION -------------------------------- //
// THIS PROGRAM SHOULD BE INVOKED TO RUN AUTOMATICALLY EVERY DAY BY
// THE OPERATING SYSTEM USING AN OPERATING SYSTEM FEATURE LIKE CRON.
// ----------------------------------------- ATTENTION -------------------------------- //

// Warning: this was only tested with MySQL. I don't have access to other databases.
// Consequently, the SQL may need tweaking for other relational databases.



// PUN_ROOT needs to be the full path name for this file
// to be run via CRON or from a htaccess protected directory

// don't forget the trailing slash!
define('PUN_ROOT', './');




require PUN_ROOT.'include/common.php';
require PUN_ROOT.'digests_include.php';
require PUN_ROOT.'lang/'.$pun_user['language'].'/digests_lang.php';

require_once PUN_ROOT.'include/email.php';




// Build an array of lowercase banned usernames
$ban_list = array();
	
foreach ($pun_bans as $cur_ban)
{
	$ban_list[] = strtolower($cur_ban['username']);
}





// Is today the day to run the weekly digest?
$today = getdate();
$mday = $today['wday'];
$current_hour = $today['hours'];
$weekly_digest_text = ($mday == $weekly_digest_day ) ? " or (digest_type = 'WEEK')" : "";

// Send a user a digest only if:
// - today is the correct day of the week for a weekly digest OR
// - they are subscribed to a daily digest

$sql = "SELECT s.user_id, u.username, u.email as user_email, u.last_visit as user_lastvisit, 
			from_unixtime(u.last_visit, '%d %b %Y %h:%m %p') as 'Last Visited', 
			s.digest_type, s.show_text, s.show_mine, s.new_only, s.send_on_no_messages, s.text_length 
			FROM " . SUBSCRIPTIONS_TABLE . " s, ".$db->prefix."users u 
			WHERE	s.user_id = u.id AND
			((s.digest_type = 'DAY')" . $weekly_digest_text . ")"; 

$result = $db->query($sql) or error('Unable to fetch user info', __FILE__, __LINE__, $db->error());



// With each pass through the loop one user will receive a customized digest.

$digests_sent = 0;
while ($row = $db->fetch_assoc($result)) 
{


	if (in_array(strtolower($row['username']), $ban_list))		// banned - do not send digest
	{

		// can be captured via command line to a file (or commented out)
		echo $row['username']." at ".$row['user_email']." is currently banned and was skipped.\n";

	}
	else {														// not banned - proceed with this user


		// get user information for the user we're editing
		$sql5 = "SELECT u.username, u.id, u.realname, u.language, u.timezone, g.g_id, g.g_user_title
					FROM " . $db->prefix."users AS u
					LEFT JOIN " . $db->prefix."groups AS g ON g.g_id=u.group_id
					WHERE u.id=" . $row['user_id'] . "";
		$result5 = $db->query($sql5) or error('Unable to fetch user info', __FILE__, __LINE__, $db->error());
		if (!$db->num_rows($result5))
			message($lang_common['Bad request']);
		$user = $db->fetch_assoc($result5);





		if ($row['new_only'] == 'TRUE') {
	
			// To filter out any possible messages a user may have seen we need to examine a number of 
			// possibilities, including last user message date/time, date/time of last session, if it exists, and
			// of course, the last access date/time in the USERS table. Of these 3 possibilities, whichever is
			// the greatest value is the actual last accessed date, and we may need to filter out messages
			// prior to this date and time. My experience is phpBB doesn't always get it right.
	
			$sql3 = 'SELECT max(posted) AS last_post_date FROM '.$db->prefix.'posts WHERE poster_id = ' . $row['user_id'];
	
			$result3 = $db->query($sql3) or error('Unable to select last post date for user.', __FILE__, __LINE__, $db->error());
			$row3 = $db->fetch_assoc($result3);
			$last_post_date = ($row3['last_post_date'] <> '') ? $row3['last_post_date'] : 0;
	
			// When did the user's last session accessed?
			$sql3 = 'SELECT max(logged) AS last_session_date 
				FROM ' . $db->prefix.'online
				WHERE user_id = ' . $row['user_id'];
	
			$result3 = $db->query($sql3) or error('Unable to get last session date for user.', __FILE__, __LINE__, $db->error());
			$row3 = $db->fetch_assoc($result3);
			$last_session_date = ($row3['last_session_date'] <> '') ? $row3['last_session_date'] : 0;
	
			$last_visited_date = $row['user_lastvisit'];
			if ($last_visited_date == '')
			{
				$last_visited_date = 0;
			}
	
			// The true last visit date is the greatest of: last_visited_date, last message posted, and last session date
			$last_visited_date = max($last_post_date, $last_session_date, $last_visited_date);
	
		}
	
		// Get a list of forums this user has subscribed to
	
		$sql3 = "SELECT s.forum_id
					FROM " . SUBSCRIBED_FORUMS_TABLE . " AS s, " . $db->prefix."forums AS f, " . $db->prefix."categories AS c
					WHERE	s.user_id = ".$user['id']." AND
							s.forum_id = f.id AND
							f.cat_id = c.id
					ORDER BY c.disp_position, f.disp_position
				";
				
		$result3 = $db->query($sql3) or error('Unable to get list of subscribed forums', __FILE__, __LINE__, $db->error());
		$queried_forums = array();
		while ($row3 = $db->fetch_assoc($result3)) 
		{
			 
			array_push($queried_forums,$row3['forum_id']);
		}
	
	
		// Create a list of forums to be queried from the database. This is a comma delimited list of all forums
		// the user is allowed to read that can be used with the SQL IN operation.
		$forum_list = array();
		$forum_list = implode(',',$queried_forums);
	
	
		// begin building the email
		
	
		// Show the text of the message?
		$show_text = ($row['show_text'] == 'YES') ? true: false; 
	
		// Show messages written by this user?
		$show_mine = ($row['show_mine'] == 'YES') ? true: false; 
	
		// Prepare to get digest type
		
		$period = ($row['digest_type'] == 'DAY') ? "1 DAY" : "7 DAY";
	
	
		// Set the part of SQL needed to retrieve new only, or messages through the selected period
		if ($row['new_only'] == 'TRUE') 
		{
			$code = 'GREATEST(UNIX_TIMESTAMP(DATE_SUB(CURRENT_DATE, INTERVAL ' . $period . ')), ' . $last_visited_date . ')'; 
		}        
		else 
		{
			$code = 'UNIX_TIMESTAMP(DATE_SUB(CURRENT_DATE, INTERVAL ' . $period . '))'; 
		}
	
		// Filter out user's own postings, if they so elected
		if ($show_mine == false)
		{
			$code .= ' and p.poster_id <> ' . $row['user_id'];
		}
	
	
		// so the relative display time for each message for this user is correct
		$diff = ($user['timezone'] - $pun_config['o_server_timezone']) * 3600;
	
	
		// Create a list of messages for this user that presumably have not been seen.
		// Filter out unauthorized forums.
		$sql2 = "SELECT c.cat_name AS cat_title, f.forum_name, t.subject AS topic_title, u.username AS 'Posted by', 
			p.posted AS post_time,
			from_unixtime((p.posted + " . $diff . "), '%a %b %d %Y, %h:%i %p') AS 'Display Time', 
			if(length(p.message)<=" . $row['text_length'] . ",p.message,concat(substring(p.message,1," . $row['text_length'] . ") ,'...')) AS 'Post Text',
			p.id AS post_id, t.id AS topic_id, f.id AS forum_id 
			FROM " . $db->prefix."posts AS p, " . $db->prefix."topics AS t, " . $db->prefix."forums AS f, " . $db->prefix."users AS u, " . 
			$db->prefix."categories AS c
			WHERE p.topic_id = t.id AND t.forum_id = f.id AND p.poster_id = u.id AND 
			f.cat_id = c.id AND 
			p.posted > " . $code . " AND f.id IN (" . $forum_list . ") 
			ORDER BY c.disp_position, f.disp_position, t.subject, p.posted
			"; 
	
		$result2 = $db->query($sql2) or error('Unable to retrieve message summary for user', __FILE__, __LINE__, $db->error());
	
	
		// Format all the mail for this user
	
		$last_forum = '';
		$last_topic = '';
		$msg        = '';
		$msg_count  = 0;
	
		while ($row2 = $db->fetch_assoc($result2)) 	// loop through each message
		{
	
	
			// BUILD THE DIGEST CONTENTS
	
	
			// Show name of forum only if it changes
			if ($row2['forum_name'] <> $last_forum) 
			{ 
				$msg .= "\r\n\r\n" . $forum_email_divider . $lang_digests['forum'] . $row2['forum_name'] . 
						"\r\n" . $pun_config['o_base_url'].'/viewforum.php?id=' . $row2['forum_id'] .
						"\r\n";
	
			}
	
			// Show name of topic only if it changes
			if ($row2['topic_title'] <> $last_topic) 
			{
				$msg .= "\r\n" . $topic_email_divider . $lang_digests['topic'] . $row2['topic_title'] . 
						"\r\n" . $pun_config['o_base_url'].'/viewtopic.php?id=' . $row2['topic_id'] .
						"\r\n";
	
			}
	
	
			// Show message information
	
			$msg .= "\r\n" . $message_email_divider . $lang_digests['posted_by'] . ' ' . $row2['Posted by']  . ' - ' . $row2['Display Time'] .
				"\r\n" . $pun_config['o_base_url'].'/viewtopic.php?id=' . $row2['topic_id'] . "#p" . $row2['post_id'] . "\r\n";
	
	
			// If requested to show the message text
			if ($show_text) 
			{
				if (strlen($row2['Post Text']) < ($row['text_length'] + 3)) 
				{
				// Remove BBCode
					$msg .= "\r\n" . preg_replace('/\[\S+\]/', '', $row2['Post Text']) . "\r\n";
				}
				else
				{
				// Remove BBCode
					$msg .= "\r\n" . $lang_digests['message_excerpt'] . preg_replace('/\[\S+\]/', '', $row2['Post Text']) . "\r\n";
				}
				$msg .= "\r\n"; 
			}
	
	
	
	
			// If the forum has changed, note the change
			if ($row2['forum_name'] <> $last_forum)
			{ 
				$last_forum = $row2['forum_name'];
			}
	
			// If the topic has changed, note the change
			if ($row2['topic_title'] <> $last_topic)
			{ 
				$last_topic = $row2['topic_title'];
			}
	
	
			$msg_count++;
			
			
		}	// end of messages loop
		
		
	
		if ($msg_count == 0)
		{
			$msg .= "\r\n\r\n" . $lang_digests['no_new_messages'] . "\r\n\r\n";
		}
	
	
	
	
		// Send the email if there are messages or if user selected to send (empty) email
		if ($msg_count > 0 || $row['send_on_no_messages'] == 'YES') {
	
			if (file_exists(PUN_ROOT.'lang/'.$user['language'].'/mail_templates/digests_email.tpl'))
			{
	
				$timestamp = getdate();
				$diff = ($user['timezone'] - $pun_config['o_server_timezone']) * 3600;
				$digest_timestamp = date("D M j Y H:i A",$timestamp[0]+$diff);
	
				// build the recipient's To: header
				$mail_to = $row['username'] . ' <' . $row['user_email'] . '>';
	
	
				// load the digest template
				$mail_tpl = trim(file_get_contents(PUN_ROOT.'lang/'.$user['language'].'/mail_templates/digests_email.tpl'));
			
				// The first row contains the subject (it also starts with "Subject:")
				$first_crlf = strpos($mail_tpl, "\n");
				$mail_subject = trim(substr($mail_tpl, 8, $first_crlf-8));
				$mail_message = trim(substr($mail_tpl, $first_crlf));
	
				$mail_subject = str_replace('<board_mailer>', $pun_config['o_board_title'], $mail_subject);
				$mail_message = str_replace('<board_mailer>', $pun_config['o_board_title'], $mail_message);
				$mail_message = str_replace('<digest_introduction>', $lang_digests['digest_introduction'], $mail_message);
				$mail_message = str_replace('<unsubscribe_url>', $lang_digests['unsubscribe_url'], $mail_message);
				$mail_message = str_replace('<digest_disclaimer>', $lang_digests['digest_disclaimer'], $mail_message);
				$mail_message = str_replace('<current_datetime>', $digest_timestamp, $mail_message);
				$mail_message = str_replace('<digest_contents>', $msg, $mail_message);
	
	
//				echo "\n\n[$mail_to]\n\n$mail_subject\n\n$mail_message\n\n";
	
				pun_mail($mail_to, $mail_subject, $mail_message);
	
				// can be captured via command line to a file (or commented out)
				$extra_s = ($msg_count == 1) ? "" : "s";
				echo 'A digest containing ' . $msg_count . ' post'. $extra_s .' was sent to ' . $row['username'] . ' at ' . $row['user_email']. "\r\n";
		
	
				$digests_sent++;
	
				$mail_subject = $mail_message = null;
	
	
			}
	
	
		}	// end of send the email 'if'



	
	}	// end of banned user 'if/else'

}	// end of user loop

// Summary information normally not seen, but can be captured via command line to a file
$hours = ($today['hours'] < 10) ? "0".$today['hours'] : $today['hours'];
$minutes = ($today['minutes'] < 10) ? "0".$today['minutes'] : $today['minutes'];
$seconds = ($today['seconds'] < 10) ? "0".$today['seconds'] : $today['seconds'];
echo 'Digests Sent: ' . $digests_sent . "\r\n";
echo 'Server Date: ' . $today['mon'] . '/' . $today['mday'] . '/' . $today['year'] . "\r\n";
echo 'Server Time: ' . $hours . ':' .  $minutes . ':' .  $seconds . "\r\n";
echo 'Server Time Zone: ' . date('Z')/3600 . ' or ' . date('T') . "\r\n";
echo "----\r\n";

?>