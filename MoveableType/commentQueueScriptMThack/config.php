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

/***************
location to dbconnect file (This should be outside your
"root" (public_html) directory.
***************/
$dbconnect = "/Volumes/CPCS Terabyte/Web/comtechreview.org_80/commentQueueScriptMThack/dbconnect.php";

/*****************
Location of where your password file will go.
This should also be outside your "root" - you can point this to the same
directory as your dbconnect.php
The script will create this file - just make sure the directory is there.
IMPORTANT!: Make sure this directory is chmod 777
******************/
$logincheck = "/Volumes/CPCS Terabyte/Web/comtechreview.org_80/commentQueueScriptMThack/password.php";


/*************
Server path to your mt install.
*************/
$mtpath = "/Volumes/CPCS\ Terabyte/Web/comtechreview.org_80/MT-2.661/";

/*************
your domain name - no "www"
if your site is not part of a subdomain include a "." before your domain name, like this: ".YOURDOMAIN.COM"
if your site IS part of a subdomain, just indicate subdomain and domain name like this: "SUBDOMAIN.DOMAIN.COM"
*************/
// $domainname = ".YOURDOMAIN.COM";
$domainname = ".comtechreview.org";

/*************
file extension used on your blog pages.
Include "." before extension.
*************/
// $fileext = ".php";
$fileext = ".html";
?>
