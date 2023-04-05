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
include("displaycommentheader.php");
?>
<html>
<head>
<title>Display Comment</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link href="styles.css" rel="stylesheet" type="text/css">

<script type="text/javascript">
function confirmSubmit()
{
var agree=confirm("Are you sure you want to delete the selected comments?");
if (agree)
	return true;
else
	return false;
}
</script>
</head>

<body>
<table width="600" border="0" align="center" cellpadding="3" cellspacing="0">
  <tr> 
    <td>
      <?
	if (isset($feedback)) {
		echo "<p>".$feedback."</p>";
		?>
		<p><a href="viewcomments.php">View All Pending Comments (Summary List)</a> | <a href="viewallcomments.php">View All Pending Comments (Full Text)</a> | <a href="logout.php">Log Out</a></p>
	<? } else { 
			if (isset($savedchanges)) {
				echo $savedchanges;
			 } ?>
<p><span class="pagetitle">View Comment</span></p>
	  <p>Review the comment below. Make changes if neccessary. When you are done, click the button to approve or delete. You can also click to save changes without approving. Comments will not show up on the site until approved.</p>
	  <p><a href="viewcomments.php">View All Pending Comments (Summary List)</a> | <a href="viewallcomments.php">View All Pending Comments (Full Text)</a> | <a href="logout.php">Log Out</a></p>
<?
include("displaycommentdbquery.php");

if ($numresults > 0) {
$row = mysql_fetch_array($result);
$entryid = sprintf("%06s",$row["comment_temp_entry_id"]);
$archivepath = $row["blog_archive_url"];
?>
      <form action="displaycomment.php" method="post" name="comments">
        <table width="100%" border="0" cellspacing="3" cellpadding="3">
          <tr> 
            <td width="0" valign="top" nowrap class="header"><p>Blog</p></td>
            <td width="83%" nowrap><? echo $row["blog_name"] ?></td>
          </tr>
		  <tr> 
            <td width="0" valign="top" nowrap class="header"><p>Post Title</p></td>
            <td width="83%" nowrap><a href="<? echo $archivepath.$entryid.$fileext ?>" target="_blank"><? echo $row["entry_title"] ?></a></td>
          </tr>
          <tr> 
            <td width="0" valign="top" nowrap class="header">
<p>Commenter's IP</p></td>
            <td nowrap><? echo $row["comment_ip"] ?></td>
          </tr>
          <tr> 
            <td width="0" valign="top" nowrap class="header">
<p>Author</p></td>
            <td nowrap><input name="comment_author" type="text" value="<? echo $row["comment_author"] ?>"></td>
          </tr>
          <tr> 
            <td width="0" valign="top" nowrap class="header">
<p>Author's Email</p></td>
            <td nowrap><input name="comment_email" type="text" value="<? echo $row["comment_email"] ?>"></td>
          </tr>
          <tr> 
            <td width="0" valign="top" nowrap class="header">
<p>Author's URL</p></td>
            <td nowrap><input name="comment_url" type="text" value="<? echo $row["comment_url"] ?>"></td>
          </tr>
          <tr> 
            <td width="0" valign="top" nowrap class="header">
<p>Comment Date</p></td>
            <td nowrap><? echo $row["comment_created_on"] ?></td>
          </tr>
          <tr> 
            <td width="0" valign="top" nowrap class="header">
<p>Comment:</p></td>
            <td><textarea name="comment_text" cols="40" rows="7"><? echo $row["comment_text"] ?></textarea></td>
          </tr>
          <tr> 
            <td colspan="2">
<input name="comment_entry" type="hidden" value="<? echo $row["comment_temp_entry_id"] ?>">
<input name="comment_id" type="hidden" value="<? echo $row["comment_id"] ?>">
<input name="comment_blog_id" type="hidden" value="<? echo $row["comment_blog_id"] ?>">
<input type="Submit" name="submit" value="Approve Comment">&nbsp;
<input type="submit" name="submit" value="Save changes">&nbsp; 
<input type="Submit" name="submit" value="Delete Comment" onClick="return confirmSubmit()">
</td>
          </tr>
        </table>
      </form>
	  <?  
	  }
	  }
	   ?>
	  </td>
  </tr>
</table>
</body>
</html>
