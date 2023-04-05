##
##
##        Mod title:  Email_Digests
##
##      Mod version:  1.0.3
##   Works on PunBB:  1.2, 1.2.1, 1.2.2, 1.2.3, 1.2.4
##     Release date:  2005-03-24
##           Author:  Terrell Russell (punbb@terrellrussell.com)
##
##      Description:  This mod will add email digest capabilities to your
##                    PunBB forums.  Options are managed for/by each user
##                    through the standard Profile pages.
##
##                    Options include:
##                    - Daily / Weekly Delivery
##                    - Display excerpt of each message
##                    - Include my messages in the digest,
##                    - Include only the messages since my last visit
##                    - Send digest, even if it will be empty
##                    - Excerpt Length
##                    - Individual forum selection
##
##                    Administrators and Moderators can manage all users'
##                    digest subscriptions.  The ban list is enforced.
##                    Time zones are honored.
##
##
##      Added files:  lang/[LANGUAGE]/mail_templates/digests_email.tpl
##                    lang/[LANGUAGE]/digests_lang.php
##                    digests_include.php
##                    digests_send_now.php
##                    digests.php
##
##   Affected files:  include/functions.php
##                    lang/[LANGUAGE]/profile.php
##
##       Affects DB:  Yes
##                    Does not affect existing tables
##                    Creates two tables to manage digest subscriptions
##
##            Notes:  Email_Digests requires the digests_send_now.php script
##                    to be run automatically by the server.  This will
##                    require access and use of the crontab.  If you have not
##                    used the crontab before, use this script with caution.
##                    A misconfigured cron file may cause havoc on server
##                    load.  This script should be set to run once daily.
##
##                    Example Cron Entry:  (would execute at 5 AM daily)
##                    0 5 * * * /path/to/php /path/to/digests_send_now.php
##
##                    Output from this script can be captured with '>>'.
##                    It will report summaries and totals.
##                    Not capturing the standard output will not affect
##                    this script's performance.
##
##                    For further notes see the included notes.txt file.
##
##
##       DISCLAIMER:  Please note that "mods" are not officially supported by
##                    PunBB. Installation of this modification is done at your
##                    own risk. Backup your forum database and any and all
##                    applicable files before proceeding.
##
##


#
#---------[ 1. UPLOAD ]-------------------------------------------------------
#

digests_email.tpl to /lang/[LANGUAGE]/mail_templates/


#
#---------[ 2. UPLOAD ]-------------------------------------------------------
#

digests_include.php to /


#
#---------[ 3. UPLOAD ]-------------------------------------------------------
#

digests_lang.php to /lang/[LANGUAGE]/


#
#---------[ 4. UPLOAD ]-------------------------------------------------------
#

digests_send_now.php to /


#
#---------[ 5. UPLOAD ]-------------------------------------------------------
#

digests.php to /


#
#---------[ 6. UPLOAD ]-------------------------------------------------------
#

install_mod.php to /


#
#---------[ 7. RUN ]----------------------------------------------------------
#

install_mod.php


#
#---------[ 8. DELETE ]-------------------------------------------------------
#

install_mod.php


#
#---------[ 9. OPEN ]---------------------------------------------------------
#

include/functions.php


#
#---------[ 10. FIND (line: ~303) ]-------------------------------------------
#

					<li<?php if ($page == 'display') echo ' class="isactive"'; ?>><a href="profile.php?section=display&amp;id=<?php echo $id ?>"><?php echo $lang_profile['Section display'] ?></a></li>
					<li<?php if ($page == 'privacy') echo ' class="isactive"'; ?>><a href="profile.php?section=privacy&amp;id=<?php echo $id ?>"><?php echo $lang_profile['Section privacy'] ?></a></li>


#
#---------[ 11. AFTER, ADD ]--------------------------------------------------
#

					<li<?php if ($page == 'digests') echo ' class="isactive"'; ?>><a href="digests.php?id=<?php echo $id ?>"><?php echo $lang_profile['Section digests'] ?></a></li>


#
#---------[ 12. FIND (line: ~678) ]-------------------------------------------
#

	$remote_address = $_SERVER['REMOTE_ADDR'];


#
#---------[ 13. REPLACE WITH ]------------------------------------------------
#

	$remote_address = isset($_SERVER['SHELL']) ? '127.0.0.1' : $_SERVER['REMOTE_ADDR']; 


#
#---------[ 14. OPEN ]--------------------------------------------------------
#

lang/[LANGUAGE]/profile.php


#
#---------[ 15. FIND (line: ~14) ]--------------------------------------------
#

'Section display'			=>	'Display',
'Section privacy'			=>	'Privacy',


#
#---------[ 16. AFTER, ADD ]--------------------------------------------------
#

'Section digests'			=>	'Email Digests',


#
#*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
#

#
#---------[ 17. IF RUNNING FROM CRON, OPEN ]----------------------------------
#

digests_send_now.php


#
#---------[ 18. FIND (line: ~42) ]--------------------------------------------
#

define('PUN_ROOT', './');


#
#---------[ 19. REPLACE WITH ]------------------------------------------------
#

define('PUN_ROOT', '/full/path/to/your/PUN_ROOT/');


#
#---------[ 20. SET CRON TO RUN DAILY - I SUGGEST 5 AM ]----------------------
#

crontab -e

0 5 * * * /path/to/php /path/to/digests_send_now.php


#
#---------[ 21. SIT BACK AND RELAX ]-----------------------------------------
#

if everything is configured correctly, email digests should soon appear.


#
#---------[ EOF ]------------------------------------------------------------
#
