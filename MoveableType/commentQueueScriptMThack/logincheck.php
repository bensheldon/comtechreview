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

if ((session_is_registered("username") && session_is_registered("password")) || ( isset($_COOKIE["queueusername"]) && isset($_COOKIE["queuepassword"]))) {
//continue...
} else {
header("Location: login.php");
exit();
}
?>
