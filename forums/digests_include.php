<?php 
/***************************************************************************
                                digests_include.php
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

// Make sure no one attempts to run this script "directly"
if (!defined('PUN'))
	exit;

// Version Number
$Email_Digests_Version = "1.0.1";


// Digest Database Table Names
// Change these if you prefer to use different table names.
// I used the "digest_" prefix to make them stand out from other standard punBB tables.

define('SUBSCRIPTIONS_TABLE',     $db->prefix.'digest_subscriptions');
define('SUBSCRIBED_FORUMS_TABLE', $db->prefix.'digest_subscribed_forums');



// Day of week to send weekly digest
// (Use 0-6 where 0=Sunday, 6=Saturday, etc.)

$weekly_digest_day     = 0;   



// these is used in the formatting of the generated emails
// probably best to end them each with "\r\n"

$forum_email_divider   = "*****************************************************************\r\n";

$topic_email_divider   = "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\r\n";

$message_email_divider = "------\r\n";

?>