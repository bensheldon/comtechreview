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
include("config.php");
include("logincheck.php");
include("$dbconnect");

if (isset($submit)) {
	mysql_pconnect("$dbserver","$dbuser","$dbpassword")
		or die("Could not connect");
	mysql_select_db("$db");
	if ($submit == "Approve Selected") {
		for($i=0; $i < count($comments); $i++) {
			//loop through each selected and update database
			$getquery = sprintf("SELECT comment_entry_id, comment_id, comment_blog_id, comment_temp_entry_id, entry_title FROM mt_comment, mt_entry WHERE comment_id='%s' and entry_id = comment_temp_entry_id;", $comments[$i]);
			
			$getresult = mysql_query($getquery);
			$getrow = mysql_fetch_array($getresult);
			$comment_entry = $getrow["comment_temp_entry_id"];
			
			$query = sprintf("UPDATE mt_comment set comment_entry_id = '%s' WHERE comment_id ='%s';", $comment_entry, $comments[$i]);
			mysql_query($query);
			
			system($mtpath."mt-rebuild.pl -mode=\"entry\" -blog_id=\"".$getrow["comment_blog_id"]."\" -entry_id=\"".$comment_entry."\"");

		}
		$feedback = "Comments successfully approved.";
		
	} else if ($submit == "Delete Selected") {
		for($i=0; $i < count($comments); $i++) {
			$query = sprintf("DELETE FROM mt_comment WHERE comment_id ='%s';", $comments[$i]);
			mysql_query($query);
		} 
		$feedback = "Your comments have successfully been deleted and will not be seen on your site";
	}// end chosing if approved or deleted
} //end if form has been submitted
?>