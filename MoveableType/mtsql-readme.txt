SQL
A Plugin for Movable Type

Release 1.52
November 5, 2002


From Brad Choate
http://www.bradchoate.com/
Copyright (c) 2002, Brad Choate


===========================================================================

INSTALLATION

To install, place the 'sql.pl' file in your Movable Type 'plugins'
directory. The 'sql.pm' file should be placed in a 'bradchoate'
subdirectory underneath your Movable Type 'extlib' directory. Your
installation should look like this:

  * (mt home)/plugins/sql.pl
  * (mt home)/extlib/bradchoate/sql.pm

Refer to the Movable Type documentation for more information regarding
plugins.

This plugin has a tag called 'SQLAuthors' that requires the 'authors'
plugin, also available from my web site:

  http://www.bradchoate.com/past/mtauthors.php


===========================================================================

DESCRIPTION

This plugin allows you to select entries, categories and comments
from your blog database using a regular SQL query.


Tags made available through this plugin:

  <MTSQL> - Allows for the selection of arbitrary data from your
  MySQL database. Use in conjunction with MTSQLColumn.

  <MTSQLColumn> - Selects a single column value from a MTSQL
  query.

  <MTSQLHeader> - Defines a header for your SQL query.

  <MTSQLFooter> - Defines a footer for your SQL query.

  <MTSQLEntries> - Allows selection of entries using a SQL query.
  This tag may contain any tags that will work in a <MTEntries>
  container tag.

  <MTSQLComments> - Allows selection of comments using a SQL query.
  This tag may contain any tags that will work in a <MTComments>
  container tag.

  <MTSQLCategories> - Allows selection of categories using a SQL
  query.  This tag may contain any tags that will work in a
  <MTCategories> container tag.

  <MTSQLPings> - Allows selection of TrackBack pings using a SQL
  query. This tag may contain any tags that will work in a
  <MTPings> container tag.

  <MTSQLAuthors> - Allows selection of authors using a SQL query.
  This tag may contain any tags that will work in a <MTAuthors>
  container tag (this tag is a separate MT plugin).


===========================================================================

<MTSQL>

These attributes are allowed:

  * query
    The SQL to execute. It can be any valid SQL select statement.

  * default
    A default value to output in case the query returns no rows.


===========================================================================

<MTSQLColumn>

These attributes are allowed:

  * column
    The number of the column (the first column is 1).

  * format
    A 'printf' format in case you want to format your output.

  * default
    A default value to output in case the column has a NULL value.
    Supports embedded expression.


===========================================================================

<MTSQLHeader>

Defines a block of HTML to be used when the first row of the query is
processed.


===========================================================================

<MTSQLFooter>

Defines a block of HTML to be used when the last row of the query is
processed.


===========================================================================

<MTSQLEntries>

These attributes are allowed:

  * query
    The SQL query to execute.  This should be a SELECT statement
    that returns as it's first column the entry_id column from the
    mt_entry table.

  * unfiltered
    If assigned '1', the tag will not attempt any additional filtering
    on the comments returned by your SELECT statement. (Normally,
    entries that don't belong to the active blog or don't have a
    'Published' status are excluded automatically.)

  * default
    A default value to output in case the column has a NULL value.
    Supports embedded expression.


Here's an example:

<MTSQLEntries query="select entry_id from mt_entry where entry_title like '%Movable Type%'">
  <a href="<MTEntryLink>"><MTEntryTitle></a><br />
</MTSQLEntries>

The above will return all blog entries you have created that have
the phrase 'Movable Type' in the entry title.


===========================================================================

<MTSQLComments>

These attributes are allowed:

  * query
    The SQL query to execute.  This should be a SELECT statement that
    returns as it's first column the comment_id column from the
    mt_comment table.

  * unfiltered
    If assigned '1', the tag will not attempt any additional filtering
    on the comments returned by your SELECT statement. (Normally,
    comments that don't belong to the active blog are excluded
    automatically.)

  * default
    A default value to output in case the column has a NULL value.
    Supports embedded expression.


This tag is designed to select comments without respect to the current
entry.


===========================================================================

<MTSQLCategories>

These attributes are allowed:

  * query
    The SQL query to execute.  This should be a SELECT statement that
    returns as it's first column the category_id column from the
    mt_category table.

  * unfiltered
    If assigned '1', the tag will not attempt any additional filtering
    on the categories returned by your SELECT statement. (Normally,
    categories that don't belong to the active blog are excluded
    automatically.)

  * default
    A default value to output in case the column has a NULL value.
    Supports embedded expression.


===========================================================================

<MTSQLPings>

  * query
    The SQL query to execute.  This should be a SELECT statement that
    returns as it's first column the tbping_id column from the
    mt_tbping table.

  * unfiltered
    If assigned '1', the tag will not attempt any additional filtering
    on the pings returned by your SELECT statement. (Normally, pings
    that don't belong to the active blog are excluded automatically.)

  * default
    A default value to output in case the column has a NULL value.
    Supports embedded expression.


===========================================================================

<MTSQLAuthors>

  * query
    The SQL query to execute.  This should be a SELECT statement that
    returns as it's first column the author_id column from the
    mt_author table.

  * unfiltered
    If assigned '1', the tag will not attempt any additional filtering
    on the authors returned by your SELECT statement. (Normally, authors
    that don't have permissions for the active blog are excluded
    automatically.)

  * default
    A default value to output in case the column has a NULL value.
    Supports embedded expression.


Please note: SQL queries are very powerful, and if you're not familiar
with the language, it will take some time to learn how to use it. The
links provided below are very helpful. Also, be patient as you are
creating them-- if they aren't working, don't assume that this plugin
is at fault-- more than likely, it is an improperly constructed query.


As a bonus, the 'query' parameter for each of these tags allows you
to embed Movable Type variables which can be evaluated! Here's how
you would form a query that uses a Movable Type variable:

<MTSQLCategories query="select category_id from mt_category where category_label like '&lt;MTArchiveTitle&gt;%' and category_label != '&lt;MTArchiveTitle&gt;'">
  <a href="<MTCategoryArchiveLink>"><MTCategoryLabel></a><br />
</MTSQLCategories>

If the above is invoked inside your category archive template, it will
list any other categories that begin with the name of the category
being processed.  For example, on my blog, I have 3 categories that
start with 'Movable Type': 'Movable Type', 'Movable Type Plugins', and
'Movable Type Tips'. For the category archive of the 'Movable Type'
category, the above query would select the other 2 categories listing
and linking to them. Note that you have to use the HTML entities for
embedded less-than, greater-than, quotes and so forth.


===========================================================================

Reference for Tables (current as of Movable Type version 2.5):

Table: mt_entry
      +----------------------+---------------+
      | Field                | Type          |
      +----------------------+---------------+
      | entry_id             | int(11)       |
      | entry_blog_id        | int(11)       |
      | entry_status         | tinyint(4)    |
      | entry_author_id      | int(11)       |
      | entry_allow_comments | tinyint(4)    |
      | entry_allow_pings    | tinyint(4)    |
      | entry_convert_breaks | tinyint(4)    |
      | entry_category_id    | int(11)       |
      | entry_title          | varchar(255)  |
      | entry_excerpt        | text          |
      | entry_text           | text          |
      | entry_text_more      | text          |
      | entry_to_ping_urls   | text          |
      | entry_pinged_urls    | text          |
      | entry_created_on     | datetime      |
      | entry_modified_on    | timestamp(14) |
      | entry_created_by     | int(11)       |
      | entry_modified_by    | int(11)       |
      | entry_keywords       | text          |
      | entry_tangent_cache  | text          |
      +----------------------+---------------+

Table: mt_comment
      +---------------------+---------------+
      | Field               | Type          |
      +---------------------+---------------+
      | comment_id          | int(11)       |
      | comment_blog_id     | int(11)       |
      | comment_entry_id    | int(11)       |
      | comment_ip          | varchar(16)   |
      | comment_author      | varchar(100)  |
      | comment_email       | varchar(75)   |
      | comment_url         | varchar(255)  |
      | comment_text        | text          |
      | comment_created_on  | datetime      |
      | comment_modified_on | timestamp(14) |
      | comment_created_by  | int(11)       |
      | comment_modified_by | int(11)       |
      +---------------------+---------------+

Table: mt_category
      +----------------------+--------------+
      | Field                | Type         |
      +----------------------+--------------+
      | category_id          | int(11)      |
      | category_blog_id     | int(11)      |
      | category_allow_pings | tinyint(4)   |
      | category_label       | varchar(100) |
      | category_description | text         |
      | category_author_id   | int(11)      |
      | category_ping_urls   | text         |
      +----------------------+--------------+

Table: mt_placement (needed for some selects between category and entry)
      +-----------------------+------------+
      | Field                 | Type       |
      +-----------------------+------------+
      | placement_id          | int(11)    |
      | placement_entry_id    | int(11)    |
      | placement_blog_id     | int(11)    |
      | placement_category_id | int(11)    |
      | placement_is_primary  | tinyint(4) |
      +-----------------------+------------+

Table mt_tbping:
      +--------------------+---------------+
      | Field              | Type          |
      +--------------------+---------------+
      | tbping_id          | int(11)       |
      | tbping_blog_id     | int(11)       |
      | tbping_tb_id       | int(11)       |
      | tbping_title       | varchar(255)  |
      | tbping_excerpt     | text          |
      | tbping_source_url  | varchar(255)  |
      | tbping_ip          | varchar(15)   |
      | tbping_blog_name   | varchar(255)  |
      | tbping_created_on  | datetime      |
      | tbping_modified_on | timestamp(14) |
      | tbping_created_by  | int(11)       |
      | tbping_modified_by | int(11)       |
      +--------------------+---------------+

Table mt_author:
      +---------------------------+--------------+
      | Field                     | Type         |
      +---------------------------+--------------+
      | author_id                 | int(11)      |
      | author_name               | varchar(50)  |
      | author_nickname           | varchar(50)  |
      | author_password           | varchar(40)  |
      | author_email              | varchar(75)  |
      | author_url                | varchar(255) |
      | author_can_create_blog    | tinyint(4)   |
      | author_can_view_log       | tinyint(4)   |
      | author_hint               | varchar(75)  |
      | author_created_by         | int(11)      |
      | author_public_key         | text         |
      | author_preferred_language | varchar(50)  |
      +---------------------------+--------------+


===========================================================================

PERFORMANCE NOTES

It is up to you to optimize your queries for maximum performance. If
you have several blogs in your database, it would be a good idea to
include selection on 'blog_id' in your WHERE clause for each table you
retrieve from.


===========================================================================

FOR MORE INFORMATION

For the MySQL database, this link should give you the official MySQL
documentation for the 'SELECT' statement:

  http://www.mysql.com/doc/S/E/SELECT.html

And this looks like a good introduction to learning SQL and
specifically, SQL SELECT statements:

  http://www.w3schools.com/sql/sql_select.asp


===========================================================================

SUPPORT

If you have any questions or need assistance with this plugin, please
visit this page of my site:

  http://www.bradchoate.com/past/mtsql.php


Brad Choate
August 1, 2002


===========================================================================

CHANGELOG

1.52 - Fixed warning issue for SQLCategories tag.

1.51 - Fixed test for checking for inner 'MTEntries' tag. Thanks to Kevin
Shay (www.staggernation.com) for the pointer.

1.5 - Queries for SQLEntries, SQLAuthors, SQLPings, SQLCategories,
SQLComments can now select any number of fields (but the respective
'id' column must be among them). Also, those tags can now use the
SQLHeader, SQLFooter and SQLColumn tags.

1.4 - The blog context will now change properly when using 'unfiltered'
queries.

1.31 - Corrected closure tags for embedded expressions.

1.3 - Added SQL, SQLColumn, SQLHeader, SQLFooter and default attribute to
all SQL* routines.

1.1 - Added SQLAuthors, SQLPings. Rearchitected plugin by separating code
into sql.pl and sql.pm.

1.0 - Initial release
