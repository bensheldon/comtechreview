<?php

// So these are set before the next array needs them
$lang_day_of_week = array(

'0'							=>	"Sunday",
'1'							=>	"Monday",
'2'							=>	"Tuesday",
'3'							=>	"Wednesday",
'4'							=>	"Thursday",
'5'							=>	"Friday",
'6'							=>	"Saturday",

);


// Language definitions used in digests.php and digests_send_now.php
$lang_digests = array(


// This block goes as default text in the emailed digest (digests_send_now.php)
'from_text_name'			=> $pun_config['o_board_title'] . ' - Digest Robot',
'from_email_address'		=> $pun_config['o_admin_email'],
'forum'						=>	'Forum: ',
'topic'						=>	'Topic: ',
'message_excerpt'			=>	'Message Excerpt: ',
'posted_by'					=>	'Posted by',
'posted_at'					=>	' at ',
'no_new_messages'			=>	'There have been no new messages for the forums you selected.',
'digest_introduction'		=>	'Here are the latest messages from the ' . $pun_config['o_board_title'] . ' forums.',
'unsubscribe_url'			=>	$pun_config['o_base_url'] . '/digests.php',
'digest_disclaimer'			=>	'This digest was sent to you automatically because you registered at ' . $pun_config['o_base_url'] . '.',




// This block goes on the digest settings user interface page (digests.php)
'Options Legend'			=>	'Digest Options',
'Options Info'				=>	"Customize your digest.",
'Forums Legend'				=>	'Forums Available',
'Forums Info'				=>	'You can select to receive summaries from any of the listed forums.',
'Type of Digest Legend'		=>	'Type of Digest',
'Type of Digest Info'		=>	'This will determine how often you receive your digest.',
'None'						=>	'None (Unsubscribe)',
'Daily'						=>	'Daily',
'Weekly'					=>	'Weekly (Currently set to send on '.$lang_day_of_week[$weekly_digest_day].'s)',
'Show Excerpt'				=>	'Display excerpt of each message',
'Show Mine'					=>	'Include my messages in the digest',
'New Only'					=>	'Include only the messages since my last visit',
'Send On No Messages'		=>	'Send digest, even if it will be empty',

'Text Length Info'			=>	'Select how long the excerpt for each message should be.',
'length_50'					=>	'50 characters',
'length_150'				=>	'150 characters',
'length_300'				=>	'300 characters',
'length_600'				=>	'600 characters',
'length_max'				=>	'Entire Message',

'Create Redirect'			=>	'Digest settings were Created successfully.',
'Update Redirect'			=>	'Digest settings were Updated successfully.',
'Unsubscribe Redirect'		=>	'Unsubscribed - Digest settings were updated successfully.',


);