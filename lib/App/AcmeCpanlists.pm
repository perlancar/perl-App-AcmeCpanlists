package App::AcmeCpanlists;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'The Acme::CPANLists CLI (backend module)',
};

sub _complete_module {
    require Complete::Module;
    my %args = @_;

    Complete::Module::complete_module(
        %args,
        ns_prefix => 'Acme::CPANLists',
    );
}

sub _complete_summary {
    require Complete::Util;
    my %args = @_;

    my $res = list_lists();
    my $array = $res->[0] == 200 ? $res->[2] : [];

    Complete::Util::complete_array(
        %args,
        array => $array,
    );
}

my %rels_filtering = (
    choose_one => [qw/mentions_author mentions_module/],
);

my %args_filtering = (
    module => {
        schema => 'str*',
        cmdline_aliases => {m=>{}},
        completion => \&_complete_module,
        tags => ['category:filtering'],
    },
    type => {
        schema => ['str*', in=>[qw/author a module m/]],
        cmdline_aliases => {t=>{}},
        tags => ['category:filtering'],
    },
    mentions_module => {
        schema => ['str*'],
        tags => ['category:filtering'],
    },
    mentions_author => {
        schema => ['str*'],
        tags => ['category:filtering'],
    },
);

my %arg_detail = (
    detail => {
        name => 'Return detailed records instead of just name/ID',
        schema => 'bool',
        cmdline_aliases => {l=>{}},
    },
);

$SPEC{list_mods} = {
    v => 1.1,
    summary => 'List all installed Acme::CPANLists modules',
    args => {
        # XXX detail
    },
};
sub list_mods {
    require PERLANCAR::Module::List;

    my $res = PERLANCAR::Module::List::list_modules(
        'Acme::CPANLists::', {list_modules=>1});

    my @res;
    for (sort keys %$res) {
        s/^Acme::CPANLists:://;
        push @res, $_;
    }

    [200, "OK", \@res];
}

$SPEC{list_lists} = {
    v => 1.1,
    summary => 'List CPAN lists',
    args_rels => {
        %rels_filtering,
    },
    args => {
        %args_filtering,
        %arg_detail,
    },
};
sub list_lists {
    no strict 'refs';

    my %args = @_;

    my $detail = $args{detail};
    my $type = $args{type};

    $type = 'a' if $args{mentions_author};
    $type = 'm' if $args{mentions_module};

    my @mods;
    if ($args{module}) {
        @mods = ($args{module});
    } else {
        my $res = list_mods();
        @mods = @{$res->[2]};
    }

    for my $mod (@mods) {
        my $mod_pm = $mod; $mod_pm =~ s!::!/!g; $mod_pm .= ".pm";
        require "Acme/CPANLists/$mod_pm";
    }

    my @cols;
    if ($detail) {
        @cols = (qw/id type summary num_entries mentioned_authors_or_modules/);
    } else {
        @cols = (qw/summary/);
    }

    my @rows;
    if (!$type || $type eq 'author' || $type eq 'a') {
        for my $mod (@mods) {
            for my $l (@{ "Acme::CPANLists::$mod\::Author_Lists" }) {
                my $entries = $l->{entries} // [];
                my $rec = {
                    type => 'author',
                    id => $l->{id},
                    module => $mod,
                    summary => $l->{summary},
                    num_entries => ~~@$entries,
                };

                my %mentioned;
                for my $ent (@$entries) {
                    $mentioned{$ent->{author}}++;
                    $mentioned{$_}++ for @{ $ent->{related_authors} // [] };
                    $mentioned{$_}++ for @{ $ent->{alternate_authors} // [] };
                }
                $rec->{mentioned_authors_or_modules} = join(", ", sort keys %mentioned);

                $rec->{_ref} = $l if $args{_with_ref};
                if ($args{mentions_author}) {
                    next unless grep {
                        $_->{author} eq $args{mentions_author}
                    } @$entries;
                }
                push @rows, $detail ? $rec : $rec->{summary};
            }
        }
    }
    if (!$type || $type eq 'module' || $type eq 'm') {
        for my $mod (@mods) {
            for my $l (@{ "Acme::CPANLists::$mod\::Module_Lists" }) {
                my $entries = $l->{entries} // [];
                my $rec = {
                    type => 'module',
                    id => $l->{id},
                    module => $mod,
                    summary => $l->{summary},
                    num_entries => ~~@$entries,
                };

                my %mentioned;
                for my $ent (@$entries) {
                    $mentioned{$ent->{module}}++;
                    $mentioned{$_}++ for @{ $ent->{related_modules} // [] };
                    $mentioned{$_}++ for @{ $ent->{alternate_modules} // [] };
                }
                $rec->{mentioned_authors_or_modules} = join(", ", sort keys %mentioned);

                $rec->{_ref} = $l if $args{_with_ref};
                if ($args{mentions_module}) {
                    next unless grep {
                        $_->{module} eq $args{mentions_module} ||
                            (defined($_->{alternate_module}) &&
                             $_->{alternate_module} eq $args{mentions_module})
                    } @$entries;
                }
                push @rows, $detail ? $rec : $rec->{summary};
            }
        }
    }

    [200, "OK", \@rows, {'table.fields'=>\@cols}];
}

$SPEC{get_list} = {
    v => 1.1,
    summary => 'Get a CPAN list as raw data',
    args_rels => {
        %rels_filtering,
    },
    args => {
        %args_filtering,
        query => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
};
sub get_list {
    no strict 'refs';

    my %args = @_;

    my $res = list_lists(
        (map {(module=>$args{$_}) x !!defined($args{$_})}
             keys %args_filtering),
        detail => 1,
        _with_ref => 1,
    );

    my @rows;
    my $type;
    for my $row (@{ $res->[2] }) {
        if (index(lc($row->{summary}), lc($args{query})) >= 0 ||
                (defined($row->{id}) &&
                         index(lc($row->{id}), lc($args{query})) >= 0)) {
            my $rec = $row->{_ref};
            $type = $row->{type};
            push @rows, $rec;
        }
    }

    if (!@rows) {
        return [404, "No such list"];
    } elsif (@rows > 1) {
        return [300, "Multiple lists found (".~~@rows."), please specify"];
    } else {
        [200, "OK", $rows[0], {'func.type'=>$type}];
    }
}

$SPEC{view_list} = {
    v => 1.1,
    summary => 'View a CPAN list as rendered POD',
    args_rels => {
        %rels_filtering,
    },
    args => {
        %args_filtering,
        query => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
};
sub view_list {
    require Pod::From::Acme::CPANLists;
    no strict 'refs';

    my %args = @_;

    my $res = get_list(%args);
    return $res unless $res->[0] == 200;

    my %podargs;
    if ($res->[3]{'func.type'} eq 'author') {
        $podargs{author_lists} = [$res->[2]];
        $podargs{module_lists} = [];
    } else {
        $podargs{author_lists} = [];
        $podargs{module_lists} = [$res->[2]];
    }
    my $podres = Pod::From::Acme::CPANLists::gen_pod_from_acme_cpanlists(
        %podargs);

    [200, "OK", $podres, {
        "cmdline.page_result"=>1,
        "cmdline.pager"=>"pod2man | man -l -"}];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

Use the included script L<acme-cpanlists>.
