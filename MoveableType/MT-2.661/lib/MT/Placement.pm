# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Placement.pm,v 1.6 2003/02/12 00:15:03 btrott Exp $

package MT::Placement;
use strict;

use MT::Object;
@MT::Placement::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'blog_id', 'entry_id', 'category_id', 'is_primary',
    ],
    indexes => {
        blog_id => 1,
        entry_id => 1,
        category_id => 1,
        is_primary => 1,
    },
    datasource => 'placement',
    primary_key => 'id',
});

1;
__END__

=head1 NAME

MT::Placement - Movable Type entry-category placement record

=head1 SYNOPSIS

    use MT::Placement;
    my $place = MT::Placement->new;
    $place->entry_id($entry->id);
    $place->blog_id($entry->blog_id);
    $place->category_id($cat->id);
    $place->is_primary(1);
    $place->save
        or die $place->errstr;

=head1 DESCRIPTION

An I<MT::Placement> object represents a single entry-category assignment; in
other words, I<MT::Placement> objects describe the assignment of entries into
categories. Each entry is assigned to one primary category and any number of
secondary categories; an I<MT::Placement> object exists for each such
assignment. An entry's assignment to its primary category is marked as a
primary placement.

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::Placement> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

=head1 DATA ACCESS METHODS

The I<MT::Placement> object holds the following pieces of data. These fields
can be accessed and set using the standard data access methods described in the
I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of the placement.

=item * entry_id

The numeric ID of the entry.

=item * category_id

The numeric ID of the category.

=item * is_primary

A boolean flag specifying whether the placement is a "primary" placement, and
hence whether it represents the entry's primary category.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * entry_id

=item * category_id

=item * is_primary

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
