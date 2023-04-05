<?php
/***************************************************************************
                                digests.php
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

// This is the user interface for the digest software.  Users can use it to create and
// modify their digest settings, or remove their digest subscription.  Moderators and Admins
// may change other users' subscriptions.

// SQL is only included for MySQL at this time.  It should be easy to add other database types.
// I do not have access to other databases and cannot test them.  Feel free to send updates (dbtype and code). 

define('PUN_ROOT', './');
require PUN_ROOT.'include/common.php';
require PUN_ROOT.'digests_include.php';
require PUN_ROOT.'lang/'.$pun_user['language'].'/digests_lang.php';
require PUN_ROOT.'lang/'.$pun_user['language'].'/profile.php';

$id = isset($_POST['id']) ? intval($_POST['id']) : $pun_user['id'];
$id = isset($_GET['id']) ? intval($_GET['id']) : $pun_user['id'];
if ($id < 2)
	message($lang_common['No permission']);  // Guests cannot see this page



// Make sure we are allowed to see / edit the digests
if ($pun_user['id'] != $id)
{
	if ($pun_user['g_id'] > PUN_MOD)	// A regular user is trying to access the digest page
		message($lang_common['No permission']);
	else if ($pun_user['g_id'] == PUN_MOD)	// A moderator is trying to access the digest page
	{
		$result = $db->query('SELECT group_id FROM '.$db->prefix.'users WHERE id='.$id) or error('Unable to fetch user info', __FILE__, __LINE__, $db->error());
		if (!$db->num_rows($result))
			message($lang_common['Bad request']);
		if ($pun_config['p_mod_edit_users'] == '0' || $db->result($result) < PUN_GUEST)
			message($lang_common['No permission']);
	}
}



// get user information for the user we're editing
$result = $db->query('SELECT u.username, u.id, u.realname, g.g_id, g.g_user_title FROM '.$db->prefix.'users AS u LEFT JOIN '.$db->prefix.'groups AS g ON g.g_id=u.group_id WHERE u.id='.$id) or error('Unable to fetch user info', __FILE__, __LINE__, $db->error());
if (!$db->num_rows($result))
	message($lang_common['Bad request']);
$user = $db->fetch_assoc($result);




if ($_SERVER['REQUEST_METHOD'] == 'GET')
{


		// get current subscription data for this user, if any
		
		$sql = 'SELECT count(*) AS count FROM ' . SUBSCRIPTIONS_TABLE . ' WHERE user_id = ' . $user['id'];
		$result = $db->query($sql) or error('Could not get count from table '. SUBSCRIPTIONS_TABLE . '.', __FILE__, __LINE__, $db->error());

		$row['count'] = 0;
   		$row = $db->fetch_assoc($result);
   		$create_new = ($row['count'] == 0) ? true: false;

		if ($create_new)
		{
			// default values if no digest subscription for this user
			
			$digest_type = 'NONE';
			$show_text = 'YES';
			$show_mine = 'YES';
			$new_only = 'TRUE';
			$send_on_no_messages = 'NO';
			$text_length = '300';
		}
		else 
		{
			// read current digest options into local variables

			$sql = 'SELECT digest_type, show_text, show_mine, new_only, send_on_no_messages, text_length FROM ' . SUBSCRIPTIONS_TABLE . ' WHERE user_id = ' . $user['id'];
			$result = $db->query($sql) or error('Could not get count from table '. SUBSCRIPTIONS_TABLE . '.', __FILE__, __LINE__, $db->error());

   			$row = $db->fetch_assoc($result);

			$digest_type           = $row['digest_type'];
			$show_text             = $row['show_text'];
			$show_mine             = $row['show_mine'];
			$new_only              = $row['new_only'];
			$send_on_no_messages   = $row['send_on_no_messages'];
			$text_length           = $row['text_length'];
		}  
    


		// Generate most of the XHTML interface here
		
		$page_title = pun_htmlspecialchars($pun_config['o_board_title']).' / '.$lang_common['Profile'];
		require PUN_ROOT.'header.php';

		generate_profile_menu('digests');

?>


	<div class="blockform">
		<h2><span><?php echo pun_htmlspecialchars($user['username']) ?> - <?php echo $lang_profile['Section digests'] ?></span></h2>
		<div class="box">
			<form id="digests" method="post" action="digests.php?id=<?php echo $id ?>">
				<div>
					<input type="hidden" name="form_sent" value="1" />
					<?php if ($create_new){ ?><input type="hidden" name="create_new" value="1" /><?php } ?>

				</div>

				<div class="inform">
					<fieldset>
						<legend><?php echo $lang_digests['Type of Digest Legend'] ?></legend>
						<div class="infldset">
							<p><?php echo $lang_digests['Type of Digest Info'] ?></p>
							<div class="rbox">
								<label><input type="radio" name="digest_type" value="NONE"<?php if ($digest_type == "NONE") echo ' checked="checked"' ?> /><?php echo $lang_digests['None'] ?><br /></label>
								<label><input type="radio" name="digest_type" value="DAY"<?php if ($digest_type == "DAY") echo ' checked="checked"' ?> /><?php echo $lang_digests['Daily'] ?><br /></label>
								<label><input type="radio" name="digest_type" value="WEEK"<?php if ($digest_type == "WEEK") echo ' checked="checked"' ?> /><?php echo $lang_digests['Weekly'] ?><br /></label>

							</div>
						</div>
					</fieldset>
				</div>
				
				<div class="inform">
					<fieldset>
						<legend><?php echo $lang_digests['Options Legend'] ?></legend>
						<div class="infldset">
							<p><?php echo $lang_digests['Options Info'] ?></p>
							<div class="rbox">
								<label><input type="checkbox" name="show_text" value="YES"<?php if ($show_text == "YES") echo ' checked="checked"' ?> /><?php echo $lang_digests['Show Excerpt'] ?><br /></label>
								<label><input type="checkbox" name="show_mine" value="YES"<?php if ($show_mine == "YES") echo ' checked="checked"' ?> /><?php echo $lang_digests['Show Mine'] ?><br /></label>
								<label><input type="checkbox" name="new_only" value="TRUE"<?php if ($new_only == "TRUE") echo ' checked="checked"' ?> /><?php echo $lang_digests['New Only'] ?><br /></label>
								<label><input type="checkbox" name="send_on_no_messages" value="YES"<?php if ($send_on_no_messages == 'YES') echo ' checked="checked"' ?> /><?php echo $lang_digests['Send On No Messages'] ?><br /></label>
							</div>
							<br />
							<br />
							<p><?php echo $lang_digests['Text Length Info'] ?></p>
							<div class="rbox">
								<label><input type="radio" name="text_length" value="50"<?php if ($text_length == "50") echo ' checked="checked"' ?> /><?php echo $lang_digests['length_50'] ?><br /></label>
								<label><input type="radio" name="text_length" value="150"<?php if ($text_length == "150") echo ' checked="checked"' ?> /><?php echo $lang_digests['length_150'] ?><br /></label>
								<label><input type="radio" name="text_length" value="300"<?php if ($text_length == "300") echo ' checked="checked"' ?> /><?php echo $lang_digests['length_300'] ?><br /></label>
								<label><input type="radio" name="text_length" value="600"<?php if ($text_length == "600") echo ' checked="checked"' ?> /><?php echo $lang_digests['length_600'] ?><br /></label>
								<label><input type="radio" name="text_length" value="32000"<?php if ($text_length == "32000") echo ' checked="checked"' ?> /><?php echo $lang_digests['length_max'] ?><br /></label>
							</div>
						</div>
					</fieldset>
				</div>
				
				<div class="inform">
					<fieldset>
						<legend><?php echo $lang_digests['Forums Legend'] ?></legend>
						<div class="infldset">
							<p><?php echo $lang_digests['Forums Info'] ?></p>
							<div class="rbox">

<?php



		// get current subscribed forums for this user, if any
		$sql = 'SELECT count(*) AS count FROM ' . SUBSCRIBED_FORUMS_TABLE . ' WHERE user_id = ' . $user['id'];
		$result = $db->query($sql) or error('Could not get count from table '. SUBSCRIBED_FORUMS_TABLE . '.', __FILE__, __LINE__, $db->error());

		$row = $db->fetch_assoc($result);
		$no_current_forums = ($row['count'] == 0) ? true : false;


		// BUILD LIST OF FORUMS THAT ARE SUBSCRIBABLE FOR THIS USER

		$sql = "SELECT c.id AS cid, c.cat_name, f.id AS forum_id, f.forum_name,
						c.disp_position as cat_order, f.disp_position as forum_order
					FROM ".$db->prefix."categories AS c
					INNER JOIN ".$db->prefix."forums AS f ON c.id=f.cat_id
					LEFT  JOIN ".$db->prefix."forum_perms AS fp ON (fp.forum_id=f.id AND fp.group_id=".$user['g_id'].")
				WHERE	(fp.read_forum IS NULL OR fp.read_forum=1) AND
						f.redirect_url IS NULL
				ORDER BY c.disp_position, c.id, f.disp_position
				";


		$result = $db->query($sql) or error('Could not query forum information', __FILE__, __LINE__, $db->error());

		$i = 0;
		while ($row = $db->fetch_assoc($result)) 
		{ 
			$forum_ids [$i] = $row['forum_id'];
			$forum_names [$i] = $row['forum_name'];
			$cat_names [$i] = $row['cat_name'];
			$cat_orders [$i] = $row['cat_order'];
			$forum_orders [$i] = $row['forum_order'];
			$i++;
		}
		$i--;

							
		// Sort forums so they appear as they would appear on the main index.
		array_multisort($cat_orders, SORT_ASC, $cat_names, SORT_ASC, $forum_orders, SORT_ASC, $forum_ids, SORT_ASC, $forum_names, SORT_ASC);

		// now print the list of forums to the interface, each forum being a checkbox with appropriate label
		for ($j=0; $j<=$i; $j++) 
		{

			// Don't print if a duplicate

			if (!(($j>0) && ($cat_orders[$j] == $cat_orders[$j-1]) && ($forum_orders[$j] == $forum_orders[$j-1]))) 

			{
    
				// Is this forum currently subscribed?
				if (!($no_current_forums)) 
				{
					$sql = 'SELECT count(*) AS count FROM ' . SUBSCRIBED_FORUMS_TABLE . ' WHERE forum_id = ' . $forum_ids[$j] . ' AND user_id = ' . $user['id'];
					$result = $db->query($sql) or error('Could not get count from table '. SUBSCRIBED_FORUMS_TABLE . '', __FILE__, __LINE__, $db->error());
					
					$row = $db->fetch_assoc($result);
					if ($row['count'] == 0)
					{
						$forum_checked = false;  // leave it unchecked
					}
					else
					{
						$forum_checked = true;   // mark it checked
					}

				}
				else  
				{
					$forum_checked = false;   // default a new user to 'not checked' - otherwise, it confuses the user
				}

			}

		// DISPLAY LIST OF FORUM CHECKBOXES HERE (ONE PER LOOP)
		
		// check to see if this forum should be displayed to this user
?>
								<label><input type="checkbox" name="forum_<?php echo $forum_ids[$j] ?>" value="1"<?php if ($forum_checked == true) echo ' checked="checked"' ?> /><?php echo pun_htmlspecialchars($cat_names[$j])." &nbsp;&raquo;&nbsp; ".pun_htmlspecialchars($forum_names[$j]) ?><br /></label>
<?php

		}


?>


							</div>
						</div>
					</fieldset>
				</div>
				<p><input type="submit" name="update" value="<?php echo $lang_common['Submit'] ?>" />  <?php echo $lang_profile['Instructions'] ?></p>
				<p><br /><br /><a href="http://punres.org/desc.php?pid=47">Email Digests <?php echo $Email_Digests_Version ?> for PunBB</a></p>
			</form>
		</div>
	</div>
</div>




<?php


	require PUN_ROOT.'footer.php';


}  // end of GET code






else   // beginning of POST code
{

	// The user has submitted the form. 
	

	// determine if any forums have been selected - regardless of the digest type

	$live_subscriptions=0;
	foreach ($_POST as $key => $value) 
	{
		if (substr($key, 0, 6) == 'forum_') 
		{
			if ($value == 1) $live_subscriptions++;
		}
	}



	if ($_POST['digest_type'] == 'NONE' || $live_subscriptions < 1)  // if 'unsubscribe' or no forums selected, remove the user's subscriptions
	{

		// remove all/any subscriptions and subscribed forums


		$sql = 'SELECT count(*) as count FROM ' . SUBSCRIPTIONS_TABLE . ' WHERE user_id = ' . $user['id'];
		$result = $db->query($sql) or error('Could not get count from table ' . SUBSCRIPTIONS_TABLE . '', __FILE__, __LINE__, $db->error());
		$row = $db->fetch_assoc($result);
		if($row['count'] != 0){

			// user no longer wants a digest
			// first remove all individual forum subscriptions
			$sql = 'DELETE FROM ' . SUBSCRIBED_FORUMS_TABLE . ' WHERE user_id = ' . $user['id'];

			$result = $db->query($sql) or error('Could not delete from table ' . SUBSCRIBED_FORUMS_TABLE . '', __FILE__, __LINE__, $db->error());

    
			// remove the subscription itself
			$sql = 'DELETE FROM ' . SUBSCRIPTIONS_TABLE . ' WHERE user_id = ' . $user['id'];

			$result = $db->query($sql) or error('Could not delete from table ' . SUBSCRIBED_FORUMS_TABLE . '', __FILE__, __LINE__, $db->error());

		}
		
		$update_type = 'unsubscribe';
    
	}

	else 
	{

		// In all other cases a digest has to be either created or updated


		// set to ENUM values if not set by the form
		$_POST['show_text']           = isset($_POST['show_text'])           ? $_POST['show_text']           : "NO";
		$_POST['show_mine']           = isset($_POST['show_mine'])           ? $_POST['show_mine']           : "NO";
		$_POST['new_only']            = isset($_POST['new_only'])            ? $_POST['new_only']            : "FALSE";
		$_POST['send_on_no_messages'] = isset($_POST['send_on_no_messages']) ? $_POST['send_on_no_messages'] : "NO";
		


		// create or update the subscription
		
		if (isset($_POST['create_new'])) // create subscription
		{
			$sql = 'INSERT INTO ' . SUBSCRIPTIONS_TABLE . ' (user_id, digest_type, show_text, show_mine, new_only, send_on_no_messages, text_length) VALUES (' .
				intval($user['id']) . ', ' .
				"'" . htmlspecialchars($_POST['digest_type']) . "', " .
				"'" . htmlspecialchars($_POST['show_text']) . "', " .
				"'" . htmlspecialchars($_POST['show_mine']) . "', " .
				"'" . htmlspecialchars($_POST['new_only']) . "', " .
				"'" . htmlspecialchars($_POST['send_on_no_messages']) . "', " .
				intval($_POST['text_length']). ')';
			$result = $db->query($sql) or error('Could not insert into table ' . SUBSCRIPTIONS_TABLE . '', __FILE__, __LINE__, $db->error());

			$update_type = 'create';

		}
		else  							// update subscription
		{
			$sql = 'UPDATE ' . SUBSCRIPTIONS_TABLE . ' SET ' .
				"digest_type = '" . htmlspecialchars($_POST['digest_type']) . "', " .
				"show_text = '" . htmlspecialchars($_POST['show_text']) . "', " .
				"show_mine = '" . htmlspecialchars($_POST['show_mine']) . "', " .
				"new_only = '" . htmlspecialchars($_POST['new_only']) . "', " .
				"send_on_no_messages = '" . htmlspecialchars($_POST['send_on_no_messages']) . "', " .
				'text_length = ' . intval($_POST['text_length']) . ' ' . 
				' WHERE user_id = ' . intval($user['id']);
			$result = $db->query($sql) or error('Could not insert or update table ' . SUBSCRIPTIONS_TABLE . '', __FILE__, __LINE__, $db->error());

			$update_type = 'modify';

			// remove any current forum subscriptions - we'll rebuild them in a second

			$sql = 'DELETE FROM ' . SUBSCRIBED_FORUMS_TABLE . ' WHERE user_id = ' . $user['id'];
			$db->query($sql) or error('Could not delete from table ' . SUBSCRIBED_FORUMS_TABLE . '', __FILE__, __LINE__, $db->error());
		

		}

		// create the individual forum subscriptions

		foreach ($_POST as $key => $value) 
		{
			if (substr($key, 0, 6) == 'forum_') 
			{					$sql = 'INSERT INTO ' . SUBSCRIBED_FORUMS_TABLE . ' (user_id, forum_id) VALUES (' .
				$user['id'] . ', ' . htmlspecialchars(substr($key,6)) . ')';
				$result = $db->query($sql) or error('Could not insert into table ' . SUBSCRIBED_FORUMS_TABLE . '', __FILE__, __LINE__, $db->error());
			}
		}


		
	}


	// DISPLAY THE RESULT - AND redirect BACK TO digests.php

	if ($update_type == 'unsubscribe'){
		redirect('digests.php?id='.$id, $lang_digests['Unsubscribe Redirect']);		
	}
	else if ($update_type == 'create'){
		redirect('digests.php?id='.$id, $lang_digests['Create Redirect']);		
	}
	else if ($update_type == 'modify'){
		redirect('digests.php?id='.$id, $lang_digests['Update Redirect']);
	}


}


?>
