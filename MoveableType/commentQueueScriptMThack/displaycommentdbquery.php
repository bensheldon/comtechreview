<?
/*
	-----------------------------------------------
		Comment Queue (Moveable Type Hack)
		Written by Jennifer of scriptygoddess.com
		
		This script is available for download on
		scriptygoddess.com.

		Please do not re-distribute or remove
		this credit line.

		If you use this script, a link back to 
		scriptygoddess would be appreciated.
	-----------------------------------------------
*/
mysql_pconnect("$dbserver","$dbuser","$dbpassword")
or die("Could not connect");
mysql_select_db("$db");

$query = sprintf("SELECT comment_id, comment_blog_id, comment_entry_id, comment_ip, comment_author, comment_email, comment_url, comment_text, comment_created_on, comment_modified_on, comment_temp_entry_id, blog_archive_url, blog_id, entry_title, entry_id, blog_name FROM mt_comment, mt_blog, mt_entry  WHERE comment_id='%s' AND comment_temp_entry_id = entry_id AND blog_id = comment_blog_id", $comment_id);

$result = mysql_query($query);
$numresults = mysql_num_rows($result);
?>