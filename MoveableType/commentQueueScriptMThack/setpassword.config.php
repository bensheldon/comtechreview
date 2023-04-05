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

if (isset($_POST['submit'])) {
	$file = fopen("$logincheck", "w+"); 
	if ($file) {
		fputs($file, crypt($_POST['password'], $_POST['username']));
		fputs($file, "\n");
		fputs($file, crypt($_POST['username'], $_POST['password']));
		fclose($file);
	}
}
?>
<html>
<head>
<title>Set Password</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<style type="text/css">
<!--
p {
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 10px;
}
h1 {
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 14px;
}
-->
</style>
</head>

<body>
<table width="300" border="0" align="center" cellpadding="0" cellspacing="0">
  <tr>
    <td>
<?
if (isset($_POST['submit'])) {
echo "Password file created. Make a local backup of this page (in case you ever want to change/reset your password - but remove it off your server";
}
?>
<h1>Set Password: </h1>
<form name="form1" method="post" action="setpassword.php">
<p>Username: <input type="text" name="username"></p>
<p>Password: <input type="password" name="password"></p>
<input type="submit" name="submit" value="submit">
</form>
</td>
  </tr>
</table>
</body>
</html>
