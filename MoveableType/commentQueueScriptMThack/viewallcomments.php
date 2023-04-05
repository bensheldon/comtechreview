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
include("viewallcommentsheader.php");
?>
<html>
<head>
<title>Dipslay Comment</title>
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
function checkAll(field)
{
for (i = 0; i < field.length; i++)
	field[i].checked = true ;
}

function uncheckAll(field)
{
for (i = 0; i < field.length; i++)
	field[i].checked = false ;
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
	<? } else if (isset($savedchanges)) {
			echo $savedchanges;
		} ?>
<p><span class="pagetitle">View All Pending Comments (Full Text)</span></p>
<?
include("viewallcommentsdbquery.php");

if ($numresults > 0) {
?>
      
	  <p>Review the comments below. You can select several and then click the 
        button to approve or delete the comments you selected. </p>
      <p><a href="viewallcomments.php">Refresh (check for new comments)</a> | 
        <a href="viewcomments.php">View All Pending Comments (Summary List)</a> 
        | <a href="logout.php">Log Out</a></p>
	  <form action="viewallcomments.php" method="post" name="comments">
<a href="javascript:checkAll(document.comments.comments)">Check All</a>&nbsp;&nbsp;&nbsp;&nbsp;<a href="javascript:uncheckAll(document.comments.comments)">Uncheck All</a>  
<?
for ($i = 0; $i <$numresults; $i++) {
$row = mysql_fetch_array($result);
$entryid = sprintf("%06s",$row["comment_temp_entry_id"]);
$archivepath = $row["blog_archive_url"];
?>
    
        <table width="100%" border="0" cellspacing="3" cellpadding="3">
          <tr>
            <td width="0" valign="top" nowrap><input name="comments[]" id="comments" type="checkbox" value="<? echo $row["comment_id"] ?>"></td>
            <td width="0" valign="top" nowrap class="header"><p>Blog</p></td>
            <td width="83%" nowrap><? echo $row["blog_name"] ?></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"><p>Post Title</p></td>
            <td width="83%" nowrap><a href="<? echo $archivepath.$entryid.$fileext ?>" target="_blank"><? echo $row["entry_title"] ?></a></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"> <p>Commenter's IP</p></td>
            <td nowrap><? echo $row["comment_ip"] ?></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"> <p>Author</p></td>
            <td nowrap><? echo $row["comment_author"] ?></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"> <p>Author's Email</p></td>
            <td nowrap><? echo $row["comment_email"] ?></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"> <p>Author's URL</p></td>
            <td nowrap><? echo $row["comment_url"] ?></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"> <p>Comment Date</p></td>
            <td nowrap><? echo $row["comment_created_on"] ?></td>
          </tr>
          <tr>
            <td width="0" valign="top" nowrap>&nbsp;</td>
            <td width="0" valign="top" nowrap class="header"> <p>Comment:</p></td>
            <td><? echo $row["comment_text"] ?></td>
          </tr>
          <tr>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td><a href="displaycomment.php?comment_id=<? echo $row["comment_id"] ?>">edit 
              this comment</a></td>
          </tr>
        </table>
        <br>
		<? } ?>
		<input type="Submit" name="submit" value="Approve Selected">&nbsp;
<input type="Submit" name="submit" value="Delete Selected" onClick="return confirmSubmit()">
</form>
	  <? } else { ?>
	  <p>There are no pending comments.</p>
	  <p><a href="viewallcomments.php">Refresh (check for new comments)</a> | 
        <a href="viewcomments.php">View All Pending Comments (Summary List)</a> 
        | <a href="logout.php">Log Out</a></p>
	  <? } ?>
	  
	  </td>
  </tr>
</table>
</body>
</html>
