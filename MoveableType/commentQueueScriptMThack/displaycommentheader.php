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

$assistant_editor = "Danielle Martin" ;

if (isset($submit)) {
	mysql_pconnect("$dbserver","$dbuser","$dbpassword")
		or die("Could not connect");
	mysql_select_db("$db");
	if ($submit == "Approve Comment") {
		$query = sprintf("UPDATE mt_comment set comment_entry_id = '%s', comment_author ='%s', comment_email = '%s', comment_url='%s', comment_text = '%s' WHERE comment_id ='%s';", $comment_entry, $comment_author, $comment_email, $comment_url, $comment_text, $comment_id);
		mysql_query($query);
		$feedback = "Comment successfully approved.";
		
		system("$mtpath".'mt-rebuild.pl -mode="entry" -blog_id='.$comment_blog_id.' -entry_id='.$comment_entry, $return) ;
// add return code check here [note that exit status should be 0, not 1]
/*
		{
			echo 'Error: entry ' . $comment_entry . ' not rebuilt. Exit code ' . $return . '.' ;
		}
*/

		// add functions to email author and comment poster that the comment has been approved.  

		// grab article author and comment author emails, if they exist 

		// when article author posts a comment, only one email should be sent (otherwise comment author + article author get two articles!)

		// get author_id from entry
// this is fucked!!!
		$article_author_id_sql = "select entry_author_id from mt_entry where entry_id = $comment_entry" ;

		$article_author_id_result = mysql_query ( $article_author_id_sql ) ;

		$article_author_id = mysql_result ( $article_author_id_result, 0, 'entry_author_id' ) ;

		// get email address, name of author
// echo 'AUTHOR ID:' . $article_author_id ;

		$article_author_info_sql = "select author_name, author_email from mt_author where author_id = $article_author_id" ; 

		$article_author_info_result = mysql_query ( $article_author_info_sql ) ;

		while ( $row = mysql_fetch_assoc ( $article_author_info_result ) )
		{
			$article_author_name = $row['author_name'] ;
			$article_author_email = $row['author_email'] ;
		}

		// FIXME: the message should include the URL of the article!
		$subject = 'ComTechReview.org: a comment has been posted to your article' ;
		$body = "Dear $article_author_name,\n\n" ;
		$body .= "We wanted to let you know that a comment on your Community Technology Review article has been posted.\n\n" ;
		$body .= "Regards,\n${assistant_editor}\nAssistant Editor" ;
		$sender = 'comments@' . $_SERVER['SERVER_NAME'] ;
		// for debugging only
		// $recipient = $article_author_email . ',saul.baizman@umb.edu' ;
		$recipient = $article_author_email ;

		// email article author
		_mail ( $sender, $recipient, $subject, $body, '' ) ;

		// check to make sure comment author and article author are not
		// the same person

		if ( $article_author_email != $comment_author )
		{
			$subject = 'ComTechReview.org: your comment has been posted' ;
			$body = "Dear $comment_author,\n\n" ;
			$body .= "We wanted to let you know that your comment on the Community Technology Review has been posted.\n\n" ;
			$body .= "Regards,\n${assistant_editor}\nAssistant Editor" ;
			$sender = 'comments@' . $_SERVER['SERVER_NAME'] ;
			$recipient = $comment_email ;

			// email comment author
			_mail ( $sender, $recipient, $subject, $body, '' ) ;

		}
		// end Saul's changes

	} else if ($submit == "Delete Comment") {
		$query = sprintf("DELETE FROM mt_comment WHERE comment_id ='%s';", $comment_id);
		mysql_query($query);
		$feedback = "Your comment has successfully been deleted and will not be seen on your site";
	} else if ($submit == "Save changes") {
		$query = sprintf("UPDATE mt_comment set comment_author ='%s', comment_email = '%s', comment_url='%s', comment_text = '%s' WHERE comment_id ='%s';", $comment_author, $comment_email, $comment_url, $comment_text, $comment_id);
		mysql_query($query);
		$savedchanges = "Your changes to this comment have been saved. This comment has still not been approved, and therefore will not yet show up on the site.";
	}// end chosing if approved or deleted
} //end if form has been submitted

/*//////////////////////////////////////////////////////////////////////////////
function: _mail
arguments: $sender, $recipient, $subject, $body, $headers
synopsis: substitute/enhancement for PHP mail() function
notes: 
//////////////////////////////////////////////////////////////////////////////*/

function _mail ( $sender, $recipient, $subject, $body, $headers = '' )
{
	$mail_headers = "From: $sender\r\n" ;
	$mail_headers .= $headers ;

	mail ( $recipient, $subject, $body, $mail_headers ) ;
}
?>
