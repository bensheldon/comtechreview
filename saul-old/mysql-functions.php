<?php

// default to mysql version 3
// not the documented behavior in using "localhost" as the hostname
/* http://us2.php.net/mysql_connect
Note: Whenever you specify "localhost" or  "localhost:port" as server, the MySQL client library will  override this and try to connect to a local socket (named pipe on Windows). If you want to use TCP/IP, use "127.0.0.1"  instead of "localhost". If the MySQL client library tries to  connect to the wrong local socket, you should set the correct path as  mysql.default_host in your PHP configuration and leave the server field  blank.
*/

////////////////////// MYSQL-SPECIFIC DATABASE FUNCTIONS ///////////////////////

/*//////////////////////////////////////////////////////////////////////////////
Function: database_error
Arguments: $database_resource (optional)
Synopsis: Reports error number and error message from a database operation
Return value: mysql_errno() and mysql_error()
Notes: a substitute for mysql_errno and mysql_error
//////////////////////////////////////////////////////////////////////////////*/

function database_error ( )
{
	// note that $database_resource is optional, and in some cases may not exist

	// FIXME: or statement with error trap here?
	// note that mysql_errno and mysql_error don't particularly care for a
	// $database_resource of ''

	return 'MySQL error #' . mysql_errno ( ) . ': ' . mysql_error ( ) ;

}

/*//////////////////////////////////////////////////////////////////////////////
Function: open_database_connection
Arguments: none
Synopsis: sucks in the global database constants DATABASE_* and connects
to a MySQL database server.
Return value: success: $db_link; failure: exit
Notes:
The PHP website mysql_connect function definition:
resource mysql_connect ( [string server [, string username [, string
password [, bool new_link [, int client_flags]]]]])
Observe that the __LINE__ and __FILE__ variables aren't helpful, since
they don't refer to the _calling_ page / line of code.
//////////////////////////////////////////////////////////////////////////////*/

function open_database_connection ( )
{

	if ( ! $db_link = @mysql_connect ( MYSQL_HOST . ':' . MYSQL_PORT, MYSQL_USERNAME, MYSQL_PASSWORD ) )
	{
		exit ;
	}
	
	if ( ! @mysql_select_db ( MYSQL_DATABASE_NAME, $db_link ) )
	{
		exit ;
	}
	else
	{
		// success! return a database resource
		return ( $db_link ) ;
	}
}

/*//////////////////////////////////////////////////////////////////////////////
Function: close_database_connection
Arguments: $db_link
Synopsis: closes the database connection and frees up the resource
Return value: success: 1; failure: 0
Notes:
//////////////////////////////////////////////////////////////////////////////*/

function close_database_connection ( $db_link )
{
	if ( ! @mysql_close ( $db_link ) )
	{
		return 0 ;
	}
	else
	{
		return 1 ;
	}
}

/*//////////////////////////////////////////////////////////////////////////////
Function: execute_sql_query
Arguments: $query, $db_link
Synopsis: pass this function a $query and a $db_link from a prior database
connection (open_database_connection).
Return value: success: $query_result; failure: 0
Notes: $db_link is optional; in fact, omitting it is preferred
//////////////////////////////////////////////////////////////////////////////*/

function execute_sql_query ( $query )
{

	if ( ! $query_result = @mysql_query ( $query ) )
	{
		// send an email, record in Apache's logfile & our custom file
		return 0 ;
	}
	else
	{
		return $query_result ;
	}
}

/*//////////////////////////////////////////////////////////////////////////////
Function: retrieve_query_result_set
Arguments: $query_result
Synopsis: grab an associative array result set from a database query.
Return value: success: $query_array; failure: 0
Notes:
//////////////////////////////////////////////////////////////////////////////*/

function retrieve_query_result_set ( $query_result )
{

	// FIXME: double check this handiwork
	// note that when the result set returns 0 rows, the
	// mysql_fetch_assoc function returns 0 for false.
	// thus, it appears to "fail" to our function

	if ( ! $query_array = @mysql_fetch_assoc ( $query_result ) )
	{
		if ( mysql_errno ( ) != 0 )
		{
		}
		return 0 ;
	}
	else 
	{
		return $query_array ;
	}
}

/*//////////////////////////////////////////////////////////////////////////////
Function: count_query_rows
Arguments: $query_result
Synopsis: returns count of affected rows in a SELECT statement
Return value: success: $num_rows; failure: nil (EXIT?)
Notes: see also mysql_affected_rows() for non-SELECT statements.
We don't go through the usual 'if it failed, return 0, otherwise return
the number,' because if a set returns 0, it evaluates to false.
If a query got this far, there's no reason the count should fail.
//////////////////////////////////////////////////////////////////////////////*/

function count_query_rows ( $query_result )
{

	if ( ( $num_rows = @mysql_num_rows ( $query_result ) ) === FALSE )
	{
		return 0 ;
	}
	else
	{
		return $num_rows ;
	}
}

/*//////////////////////////////////////////////////////////////////////////////
Function: free_query_result_set
Arguments: $query_result
Synopsis: frees up memory taken by give $query_result
Return value: 
Notes: see mysql_free_result() 
//////////////////////////////////////////////////////////////////////////////*/

function free_query_result_set ( $query_result )
{

	if ( ! mysql_free_result ( $query_result ) )
	{
		return 0 ;
	}
	else
	{
		return 1 ;
	}

}

/*//////////////////////////////////////////////////////////////////////////////
Function: get_last_insert_id
Arguments: none
Synopsis: get last_insert_id() from previos INSERT statement
Return value: 
Notes: see mysql_insert_id() 
//////////////////////////////////////////////////////////////////////////////*/

function get_last_insert_id ( )
{

	if ( ! $last_insert_id = mysql_insert_id ( ) )
	{
		return 0 ;
	}
	else
	{
		return $last_insert_id ;
	}

}

/*//////////////////////////////////////////////////////////////////////////////
Function: retrieve_one_query_cell
Arguments: $result
Synopsis: get one cell from a query
Return value: 
Notes: see mysql_result() 
//////////////////////////////////////////////////////////////////////////////*/

function retrieve_one_query_cell ( $result )
{

	if ( ! $cell_contents = mysql_result ( $result, 0 ) )
	{
		return 0 ;
	}
	else
	{
		return $cell_contents ;
	}

}

?>
