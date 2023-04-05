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

	$loginInfo = file($logincheck);
	if (crypt($_POST['password'], $_POST['username']) == trim($loginInfo[0]) && crypt($_POST['username'], $_POST['password']) == trim($loginInfo[1])) {
		session_start();
		$username = crypt($_POST['username'], $_POST['password']);
		$password = crypt($_POST['password'], $_POST['username']);
		 session_register("username");
		 session_register("password");
		 if (isset($_POST['rememberme'])) {
		 	setcookie("queueusername", $username, time()+126144000,"/", $domainname, 0);
			setcookie("queuepassword", $password, time()+126144000,"/", $domainname, 0);
		 }
		 /*
		 change http path below to point to the page you want people to go to after they login
		 */
		 header("Location: viewcomments.php");
		 exit();
	} else {
	$feedback = "Username and/or password is incorrect.";
	}
}
?>
<html>
<head>
<title>Login</title>
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
if (isset($feedback)) {
echo $feedback;
}
?>
      <h1>CTR.org Comment Review Login: </h1>
<form name="form1" method="post" action="login.php">
        <table width="100%" border="0" cellspacing="0" cellpadding="3">
          <tr> 
            <td><p>Username:</p></td>
            <td><input type="text" name="username"></td>
          </tr>
          <tr> 
            <td><p>Password:</p></td>
            <td><input type="password" name="password"></td>
          </tr>
          <tr>
            <td>&nbsp;</td>
            <td><p>
                <input type="checkbox" name="rememberme" value="rememberme">
                Remember me</p></td>
          </tr>
        </table>
<input type="submit" name="submit" value="submit">
</form>
</td>
  </tr>
</table>
</body>
</html>
