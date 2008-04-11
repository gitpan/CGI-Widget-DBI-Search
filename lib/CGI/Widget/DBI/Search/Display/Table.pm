package CGI::Widget::DBI::Search::Display::Table;

use strict;

use base qw/ CGI::Widget::DBI::Search::Base /;

sub new {
    my ($this, $search) = @_;
    my $class = ref($this) || $this;
    my $self = bless {}, $class;
    $self->{s} = $search if $search;
    $self->{q} = $search->{q} if $search->{q};
    return $self;
}

=head1 NAME

CGI::Widget::DBI::Search::Display::Table - HTML table display class for Search widget

=head1 SYNOPSIS

  This class is not intended to be used directly

=head1 DESCRIPTION

This class displays search results retrieved in the search widget in HTML table format.

=head1 METHODS

=item _set_display_defaults()

Sets object variables for displaying search results.  Called from display() method.

=cut

sub _set_display_defaults {
    my ($self) = @_;
    $self->{'action_uri'} = $self->{-action_uri} || $ENV{SCRIPT_NAME};

    if (ref $self->{-href_extra_vars} eq "HASH") {
        $self->{'href_extra_vars'} = join('&', map {
            "$_=".(defined $self->{-href_extra_vars}->{$_}
                   ? $self->{-href_extra_vars}->{$_}
                   : $self->{q}->param($_));
        } keys %{$self->{-href_extra_vars}});
    } elsif ($self->{-href_extra_vars}) {
        $self->{'href_extra_vars'} = $self->{-href_extra_vars};
    }
    $self->{'href_extra_vars'} = '&'.$self->{'href_extra_vars'}
      unless $self->{'href_extra_vars'} =~ m/^&/;
}

=item display()

Displays an HTML table of data values stored in the search widget's 'results'  object variable
(retrieved from the most recent call to its search() method).

=cut

sub display {
    my ($self) = @_;
    my $q = $self->{q};

    $self->_set_display_defaults();

    # read ordered list of table columns
    my @sql_table_columns = ref $self->{s}->{-sql_retrieve_columns} eq "ARRAY"
      ? @{$self->{s}->{-sql_retrieve_columns}} : @{$self->{s}->{-sql_table_columns}};
    my @pre_nondb_columns = ref $self->{-pre_nondb_columns} eq "ARRAY"
      ? @{$self->{-pre_nondb_columns}} : ();
    my @post_nondb_columns = ref $self->{-post_nondb_columns} eq "ARRAY"
      ? @{$self->{-post_nondb_columns}} : ();

    $self->{-display_columns} =
      { map {my $c=$_; $c =~ s/.*[. ](\w+)$/$1/; $c=>$c} @sql_table_columns }
	unless ref $self->{-display_columns} eq "HASH";

#    if ($q->param('page_sortby') and
#	!$self->{s}->{-unsortable_columns}->{$q->param('page_sortby')}) {
#	$self->pagesort_results($q->param('page_sortby'),
#			    $self->{'page_sortby'} eq $q->param('page_sortby'));
#    }

    # build displayed column headers along with sort links and direction arrow
    my (@cols, $header_labels, @rows);
    foreach my $col (@pre_nondb_columns, @sql_table_columns, @post_nondb_columns) {
	# remove any "tbl." if SQL stmt uses tbl aliases
	$col =~ s/.*[. ](\w+)$/$1/;
	if ($self->{-display_columns}->{$col}) {
	    push(@cols, $col);
	    if ($self->{-unsortable_columns}->{$col}) {
		$header_labels .=
		  $q->td({-bgcolor => $self->{s}->TABLE_HEADER_BGCOLOR(),
			  ($self->{-currency_columns}->{$col}
                           || $self->{-numeric_columns}->{$col}
			   ? (-align=>'right') : ()), -nowrap=>1},
			 $self->{-display_columns}->{$col});
	    } else {
		# if no page_sortby column was set, use first sortable one
		#$self->pagesort_results($col) unless $self->{'page_sortby'};
		$header_labels .= $q->td
		  ({-bgcolor => $self->{s}->TABLE_HEADER_BGCOLOR(),
		    ($self->{-currency_columns}->{$col}
                     || $self->{-numeric_columns}->{$col}
		     ? (-align=>'right') : ()), -nowrap=>1},
		   ($col eq $self->{s}->{'sortby'} ? "<B>" : "") .
		   $q->a({-href => $self->{s}->BASE_URI().$self->{'action_uri'}.
			  '?sortby='.$col.
			  ($col eq $self->{s}->{'sortby'}
			   ? '&sort_reverse='.(!$self->{s}->{'sort_reverse'}) : '').
			  $self->{'href_extra_vars'}},
			 $self->{-display_columns}->{$col}) . " " .
		   ($col eq $self->{s}->{'sortby'}
		    ? ($self->{s}->{'sort_reverse'} ? '\\/' :'/\\')."</B>"
		    : ''));
	    }
	}
    }

    # iterate over most recently returned 'results', which should be a
    # (possibly blessed) hashref
    my $color;
    foreach my $row (@{$self->{s}->{'results'}}) {
	# toggle color
	$color = (($color||'') eq $self->{s}->TABLE_BGCOLOR2()
		  ? $self->{s}->TABLE_BGCOLOR1()
		  : $self->{s}->TABLE_BGCOLOR2());

	# build a table row
	push(@rows, join '', map {
	    (ref $self->{-columndata_closures}->{$_} eq "CODE"
	     ? $self->{-columndata_closures}->{$_}->($self, $row, $color)
	     : $self->{-currency_columns}->{$_}
	     ? $q->td({-bgcolor => $color, -align => 'right'},
		      sprintf('$%.2f', $row->{$_}))
	     : $self->{-numeric_columns}->{$_}
             ? $q->td({-bgcolor => $color, -align => 'right'}, $row->{$_})
	     : $q->td({-bgcolor => $color}, $row->{$_}))
	} @cols );
    }

    my ($prevlink, $nextlink, $firstlink, $lastlink) = (
        make_nav_uri($self, $self->{s}->{'page'} - 1),
        make_nav_uri($self, $self->{s}->{'page'} + 1),
        make_nav_uri($self, 0),
        make_nav_uri($self, $self->{s}->{'lastpage'}),
    );

    return
      ($self->{-optional_header} .

       $self->display_pager_links
       ($self->{s}->{'page'}, $#{$self->{s}->{'results'}}+1,
	$self->{s}->{-max_results_per_page}, $self->{s}->{'numresults'},
	$prevlink, $nextlink, $firstlink, $lastlink, 1) .

       $q->table
       ({-cellpadding => $self->{-display_table_padding} ? $self->{-display_table_padding} : '2',
	 -width => '96%'}, $q->Tr([ $header_labels, @rows ])) .

       $self->display_pager_links
       ($self->{s}->{'page'}, $#{$self->{s}->{'results'}}+1,
	$self->{s}->{-max_results_per_page}, $self->{s}->{'numresults'},
	$prevlink, $nextlink, $firstlink, $lastlink, undef, 1) .

       $self->{-optional_footer}
      );
}

=item make_nav_uri( $page_no )

Generates and returns a URI for a given page number in the search result set.
Pages start at 0, with each page containing at most -max_results_per_page.

=cut

sub make_nav_uri {
    my ($self, $page_no) = @_;
    my $link = $self->{s}->BASE_URI().$self->{'action_uri'}.'?search_startat='.$page_no;
    if ($self->{s}->{-no_persistent_object} && $self->{s}->{'sortby'}) {
        $link .= '&sortby=' . ($self->{s}->{'sortby'}||'')
          . '&sort_reverse=' . ($self->{s}->{'sort_reverse'}||'');
    }
    $link .= $self->{'href_extra_vars'} || '';
    return $link;
}


=item display_pager_links($startat, $pagetotal, $maxpagesize, $searchtotal,
			  $prevlink, $nextlink, $firstlink, $lastlink, $showtotal)

Returns an HTML table containing navigation links for first, previous, next,
and last pages of result set.  This method is called from display()
and should be treated as a protected method.

parameters:
  $startat	page of results on which to start
  $pagetotal	number of items on *this* page
  $maxpagesize	size of page: maximum number of items to show per page
  $searchtotal	total number of items returned by search
  $prevlink	HTML href link to previous page of results
  $nextlink	HTML href link to next page of results
  $firstlink	HTML href link to first page of results
  $lastlink	HTML href link to last page of results
  $showtotal	boolean to toggle whether to show total number
                of results along with range on current page
  $showpages    boolean to toggle whether to show page range links
                for easier navigation in large datasets
                (has no effect unless a value for $searchtotal is passed)

=back

=cut

sub display_pager_links {
    my ($self, $startat, $pagetotal, $maxpagesize, $searchtotal,
	$prevlink, $nextlink, $firstlink, $lastlink, $showtotal, $showpages) = @_;
    my $q = $self->{q};
    my $middle_column = $showtotal || $showpages && $searchtotal;
    return
      ($q->table
       ({-width => '96%'}, $q->Tr
	($q->td({-align => 'left',
		 -width => $middle_column ? '30%' : '50%'},
		$q->font({-size => '-1'},
			 ($startat > 0
			  ? $q->b(($firstlink
				   ? $q->a({-href =>$firstlink},
					   "|&lt;First").'&nbsp;&nbsp;&nbsp;'
				   : '').
				  $q->a({-href =>$prevlink}, "&lt;Previous"))
			  : "|At first page"))) .
	 ($middle_column
	  ? $q->td({-align => 'center', -width => '40%', -nowrap => 1},
                   ($showtotal
                    ? "<B>$pagetotal</B> result".
                      ($pagetotal == 1 ? '' : 's')." displayed".
                      ($searchtotal
                       ? (': <B>'.($startat*$maxpagesize + 1).' - '.
                          ($startat*$maxpagesize + $pagetotal).'</B> of <B>'.
                          $searchtotal.'</B>')
                       : '').$q->br
                    : '') .
                    ($showpages && $searchtotal
                     ? $q->font({-size => '-1'},
                                "Skip to page: ".display_page_range_links($self, $startat))
                     : '')
                  )
	  : '') .
	 $q->td({-align => 'right', -width => $middle_column ? '30%' : '50%'},
		$q->font({-size => '-1'},
			 (defined $maxpagesize &&
			  ((defined $searchtotal
			    && $startat != int(($searchtotal-1)/$maxpagesize))
			   || (!$searchtotal && $pagetotal >= $maxpagesize))
			  ? $q->b($q->a({-href =>$nextlink}, "Next&gt;").
				  ($lastlink
				   ? '&nbsp;&nbsp;&nbsp;'.$q->a({-href =>$lastlink},"Last&gt;|")
				   : ''))
			  : "At last page|"))))
       ));
}


=item display_page_range_links()

Returns a chunk of HTML which shows links to the surrounding pages in the search set.
The number of pages shown is determined by the -page_range_nav_limit setting.

=cut

sub display_page_range_links {
    my ($self, $startat) = @_;
    my $q = $self->{q};
    my (@page_range, $pre, $post) = ((), '', '');
    if ($startat <= $self->{-page_range_nav_limit}
          && $startat + $self->{-page_range_nav_limit} >= $self->{s}->{'lastpage'}) {
        @page_range = 0 .. $self->{s}->{'lastpage'};
    } elsif ($startat <= $self->{-page_range_nav_limit}) {
        @page_range = 0 .. ($startat + $self->{-page_range_nav_limit});
        $post = ' ...';
    } elsif ($startat + $self->{-page_range_nav_limit} >= $self->{s}->{'lastpage'}) {
        @page_range = ($startat - $self->{-page_range_nav_limit}) .. $self->{s}->{'lastpage'};
        $pre = '... ';
    } else {
        @page_range = ($startat - $self->{-page_range_nav_limit}) .. ($startat + $self->{-page_range_nav_limit});
        $pre = '... ';
        $post = ' ...';
    }
    return $pre.join(' ', map {
        $startat == $_ ? $q->b($_) : $q->a({-href => make_nav_uri($self, $_)}, $_)
    } @page_range).$post;
}


1;
