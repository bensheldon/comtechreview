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
session_start();
session_unset();
session_destroy();
include("config.php");
setcookie("queueusername", "", time()-3600,"/", ".$domainname", 0);
setcookie("queuepassword", "", time()-3600,"/", ".$domainname", 0);

/*
edit the http path below to point to the page you want people to go to after they logout
*/
header("Location: login.php");
exit();
?>