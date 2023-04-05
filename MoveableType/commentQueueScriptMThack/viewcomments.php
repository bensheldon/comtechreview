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
include("viewcommentsheader.php")
?>
<html>
<head>
<title>View Comments</title>
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
	}
?>
<p><span class="pagetitle">View All Pending Comments (Summary List)</span></p>
<?
include("viewcommentsdbquery.php");
if ($numresults > 0) {
?>
	
	  <p>Click on the header name to sort by that field. You can select multiple 
        comments to approve or delete them at once. To view a single comment, 
        click on &quot;view comment&quot;.</p>
      <p><a href="viewcomments.php">Refresh (check for new comments)</a> | <a href="viewallcomments.php">View 
        All Pending Comments (Full Text)</a> | <a href="logout.php">Log Out</a></p>
	<form action="viewcomments.php" method="post" name="comments">
<a href="javascript:checkAll(document.comments.comments)">Check All</a>&nbsp;&nbsp;&nbsp;&nbsp;<a href="javascript:uncheckAll(document.comments.comments)">Uncheck All</a>

<table width="100%" border="0" cellspacing="3" cellpadding="3">
<tr class="header">
	<td>&nbsp;</td>
	<td>&nbsp;</td>
	<td><a href="viewcomments.php?orderby=blog_id">Issue</a></td>
	<td><a href="viewcomments.php?orderby=comment_author">Author</a></td>
	<td><a href="viewcomments.php?orderby=comment_email">Author's Email</a></td>
	<td><a href="viewcomments.php?orderby=comment_url">Author's URL</a></td>
	<td><a href="viewcomments.php?orderby=entry_title">Post Title</a></td>
	<td><a href="viewcomments.php?orderby=comment_ip">Commenter's IP</a></td>
	<td><a href="viewcomments.php?orderby=comment_created_on">Comment Date</a></td>
</tr>
<?
for ($i = 0; $i <$numresults; $i++) {
$row = mysql_fetch_array($result);
$entryid = sprintf("%06s",$row["comment_temp_entry_id"]);
$archivepath = $row["blog_archive_url"];
?>

<tr <? if ($i%2) { ?>class="dataeven"<? } else { ?> class="data"<? } ?>>
<td nowrap><a href="displaycomment.php?comment_id=<? echo $row["comment_id"] ?>">view</a></td>
<td nowrap><input name="comments[]" id="comments" type="checkbox" value="<? echo $row["comment_id"] ?>"></td>
<td nowrap><? echo $row["blog_name"] ?></td>
	<td nowrap><? echo $row["comment_author"] ?></td>
	<td nowrap><? echo $row["comment_email"] ?></td>
	<td nowrap><? echo $row["comment_url"] ?></td>
	<td nowrap><a href="<? echo $archivepath.$entryid.$fileext ?>" target="_blank"><? echo $row["entry_title"] ?></a></td>
	<td nowrap><? echo $row["comment_ip"] ?></td>
	<td nowrap><? echo $row["comment_created_on"] ?></td>
    </tr>
	<?
	}
	?>
  <tr>
  <td colspan="7"><input type="Submit" name="submit" value="Approve Selected">&nbsp;<input type="Submit" name="submit" value="Delete Selected" onClick="return confirmSubmit()">
  </td>
  </tr>
</table>
</form>
<? } else { ?>
<p>There are no pending comments.</p>
      <p><a href="viewcomments.php">Refresh (check for new comments)</a> | <a href="viewallcomments.php">View 
        All Pending Comments (Full Text)</a> | <a href="logout.php">Log Out</a></p>
<? } ?>
</td>
  </tr>
</table>

</body>
</html>
