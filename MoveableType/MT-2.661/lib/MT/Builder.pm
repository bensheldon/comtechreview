# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Builder.pm,v 1.23 2003/02/12 00:15:03 btrott Exp $

package MT::Builder;
use strict;

use MT::ErrorHandler;
@MT::Builder::ISA = qw( MT::ErrorHandler );

sub new { bless { }, $_[0] }

sub compile {
    my $build = shift;
    my($ctx, $text) = @_;
    return [ ] unless $text;
    my $state = local $build->{__state} = { tokens => [ ] };
    $state->{text} = \$text;
    my $pos = 0;
    my $len = length $text;
    while ($text =~ m!(<\$?MT(.+?)[\$/]?>)!gs) {
        my($whole_tag, $tag) = ($1, $2);
        ($tag, my($args)) = split /\s+/, $tag, 2;
        my $sec_start = pos $text;
        my $tag_start = $sec_start - length $whole_tag;
        _text_block($state, $pos, $tag_start) if $pos < $tag_start;
        $args ||= '';
        my %args;
        while ($args =~ /(\w+)\s*=\s*(["'])(.*?)\2/gs) {
            $args{$1} = $3;
        }
        my($h, $is_container) = $ctx->handler_for($tag);
        my $rec = [ $tag, \%args ];
        if ($is_container) {
            if ($whole_tag !~ m|/>|) {
                my ($sec_end, $tag_end) = _consume_up_to(\$text, $sec_start, $tag);
                if ($sec_end) {
                    my $sec = substr $text, $sec_start, $sec_end - $sec_start;
                    $sec =~ s!^\n!!;
                    $rec->[2] = $build->compile($ctx, $sec) or return;
                    $rec->[3] = $sec;
                } else {
                    return $build->error("<MT$tag> with no </MT$tag>");
                }
                $pos = $tag_end + 1;
                (pos $text) = $tag_end;
            } else {
                $rec->[3] = '';
                $pos = pos $text;
            }
        } else {
            $pos = pos $text;
        }
        push @{ $state->{tokens} }, $rec;
        $pos = pos $text;
    }
    _text_block($state, $pos, $len) if $pos < $len;
    $state->{tokens};
}

sub _consume_up_to {
    my($text, $start, $stoptag) = @_;
    my $pos;
    (pos $$text) = $start;
    while ($$text =~ m!(<([\$/]?)MT($stoptag[^>]*?)[\$/]?>)!g) {
        my($whole_tag, $prefix, $tag) = ($1, $2, $3);
        ($tag, my($args)) = split /\s+/, $tag, 2;
        next if $tag ne $stoptag;
        my $end = pos $$text;
        if ($prefix && ($prefix eq '/')) {
            return ($end - length($whole_tag), $end);
        } elsif ($whole_tag !~ m|/>|) {
            my ($sec_end, $end_tag) = _consume_up_to($text, $end, $tag);
            last if !$sec_end;
            (pos $$text) = $end_tag;
        }
    }
    return (0, 0);
}

sub _text_block {
    my $text = substr ${ $_[0]->{text} }, $_[1], $_[2] - $_[1];
    push @{ $_[0]->{tokens} }, [ 'TEXT', $text ] if $text;
}

sub build {
    my $build = shift;
    my($ctx, $tokens, $cond) = @_;
    $cond ||= { };
    $ctx->stash('builder', $build);
    my $res = '';
    my $ph = $ctx->post_process_handler;
    for my $t (@$tokens) {
        if ($t->[0] eq 'TEXT') {
            $res .= $t->[1];
        } else {
            my($tokens, $uncompiled);
            if (exists $cond->{ $t->[0] } && !$cond->{ $t->[0] }) {
                for my $tok (@{ $t->[2] }) {
                    if ($tok->[0] eq 'Else') {
                        $tokens = $tok->[2];
                        $uncompiled = $tok->[3];
                        last;
                    }
                }
                next unless $tokens;
            } else {
                if ($t->[2] && ref($t->[2]) eq 'ARRAY') {
                    $tokens = [ grep $_->[0] ne 'Else', @{ $t->[2] } ];
                }
                $uncompiled = $t->[3];
            }
            my($h) = $ctx->handler_for($t->[0]);
            if ($h) {
                $ctx->stash('tag', $t->[0]);
                $ctx->stash('tokens', $tokens);
                $ctx->stash('uncompiled', $uncompiled);
                local $t->[1] = $t->[1];
                my $out = $h->($ctx, $t->[1], $cond);
                return $build->error("Error in <MT$t->[0]> tag: " .
                                     $ctx->errstr) unless defined $out;
                if ($ph) {
                    $out = $ph->($ctx, $t->[1], $out);
                }
                $res .= $out;
            }
        }
    }
    $res;
}

1;
__END__

=head1 NAME

MT::Builder - Parser and interpreter for MT templates

=head1 SYNOPSIS

    use MT::Builder;
    use MT::Template::Context;

    my $build = MT::Builder->new;
    my $ctx = MT::Template::Context->new;

    my $tokens = $build->compile($ctx, '<$MTVersion$>')
        or die $build->errstr;
    defined(my $out = $build->build($ctx, $tokens))
        or die $build->errstr;

=head1 DESCRIPTION

I<MT::Builder> provides the parser and interpreter for taking a template
body and turning it into a generated output page. An I<MT::Builder> object
knows how to parse a string of text into tokens, then take those tokens and
build a scalar string representing the output of the page. It does not,
however, know anything about the types of tags that it encounters; it hands
off this work to the I<MT::Template::Context> object, which can look up a
tag and determine whether it's valid, whether it's a container or substitution
tag, etc.

All I<MT::Builder> knows is the basic structure of a Movable Type tag, and
how to break up a string into pieces: plain text pieces interspersed with
tag callouts. It then knows how to take a list of these tokens/pieces and
build a completed page, using the same I<MT::Template::Context> object to
actually fill in the values for the Movable Type tags.

=head1 USAGE

=head2 MT::Builder->new

Constructs and returns a new parser/interpreter object.

=head2 $build->compile($ctx, $string)

Given an I<MT::Template::Context> object I<$ctx>, breaks up the scalar string
I<$string> into tokens and returns the list of tokens as a reference to an
array. Returns C<undef> on compilation failure.

=head2 $build->build($ctx, \@tokens [, \%cond ])

Given an I<MT::Template::Context> object I<$ctx>, turns a list of tokens
I<\@tokens> and generates an output page. Returns the output page on success,
C<undef> on failure. Note that the empty string (C<''>) and the number zero
(C<0>) are both valid return values for this method, so you should check
specifically for an undefined value when checking for errors.

The optional argument I<\%cond> specifies a list of conditions under which
the tokens will be interpreted. If provided, I<\%cond> should be a reference
to a hash, where the keys are MT tag names (without the leading C<MT>), and
the values are boolean flags specifying whether to include the tag; a true
value means that the tag should be included in the final output, a false value
that it should not. This is useful when a template includes conditional
container tags (eg C<E<lt>MTEntryIfExtendedE<gt>>), and you wish to influence
the inclusion of these container tags. For example, if a template contains
the container

    <MTEntryIfExtended>
    <$MTEntryMore$>
    </MTEntryIfExtended>

and you wish to exclude this conditional, you could call I<build> like this:

    my $out = $build->build($ctx, $tokens, { EntryIfExtended => 0 });

=head1 ERROR HANDLING

On an error, the above methods return C<undef>, and the error message can
be obtained by calling the method I<errstr> on the object. For example:

    defined(my $out = $build->build($ctx, $tokens))
        or die $build->errstr;

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
