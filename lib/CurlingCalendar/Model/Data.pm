package CurlingCalendar::Model::Data 0.99;

use 5.014;
use DateTime::Format::Strptime;
use Mojo::Collection;

sub get_season {
    my ($self, $league, $year, $division, $dom) = @_;

    my $season = CurlingCalendar::Model::Data::Season->new(
        league => $league,
        division => $division,
        year => $year,
    );


    my $fmt = DateTime::Format::Strptime->new(
        pattern => '%Y/%d/%m %R',
        locale => 'nb_NO',
        time_zone => 'Europe/Oslo',
        on_error => 'croak',
    );
    $dom->find('table tr')->each(sub {
            state $count = 0;
            my $row = shift;
            if ($count) {
                # this is a proper row
                my $d = $row->child_nodes->map('text')->flatten->compact->to_array;
                return unless scalar(@$d);
                my $date = $fmt->parse_datetime(
                    ($d->[0] =~ m|/1\d$| ? '2015' : '2016') . "/" . shift(@$d)
                    . " " . shift(@$d)
                );
                my $location = shift(@$d) . ", " . shift(@$d);
                my $res;
                if (scalar(@$d) > 2) {
                    # We have a result
                    $res = join(" ", @$d[2..4]);
                }

                $season->add_match(CurlingCalendar::Model::Data::Match->new(
                        home => $d->[0],
                        away => $d->[1],
                        time => $date,
                        location => $location,
                        result => $res,
                    )
                );
            }
            $count++;
        }
    );
    return $season;

}


package CurlingCalendar::Model::Data::Season {
    use Moo;

    has league => (
        is => 'ro',
        required => 1,
    );
    has division => (
        is => 'ro',
        required => 1,
    );
    has year => (
        is => 'ro',
        required => 1,
    );
    has matches => (
        is => 'ro',
        default => sub { Mojo::Collection->new() },
        handles => [qw/each size/],
    );

    sub add_match {
        my ($self, $match ) = @_;

        push(@{ $self->matches }, $match);
    }

    sub matches_for_team {
        my ($self, $team) = @_;
        return $self->new(
            league => $self->league,
            year => $self->year,
            division => $self->division,
            matches => $self->matches->grep('is_team_playing', $team)
        );
    }

    sub as_table {
        my $self = shift;

        # Re-format the data to a table?
        my %teams = ();
        $self->matches->each(sub {
                my $m = shift;
                for (qw/home away/) {
                    $teams{$m->$_} = {
                        name => $m->$_,
                        points => 0,
                        played => 0,
                        beat => {},
                    } unless exists $teams{$m->$_};
                    $teams{$m->$_}->{played}++ if $m->result;
                }
                if ($m->result) {
                    my $score = eval $m->result;
                    if (eval $m->result > 0) {
                        $teams{$m->home}->{points}++;
                        $teams{$m->home}->{beat}->{$m->away} = 1;

                    } else {
                        $teams{$m->away}->{points}++;
                        $teams{$m->away}->{beat}->{$m->home} = 1;
                    }
                }
            }
        );
        my $table = CurlingCalendar::Model::Data::Table->new();
        foreach my $t (sort { 
                $teams{$b}->{points} <=> $teams{$a}->{points}
                || # equal points, need to look at more data somehow..?
                ($teams{$b}->{beat}->{$a} // 0) <=> ($teams{$a}->{beat}->{$b} // 0)
            } keys %teams) {
            push(@{ $table->entries }, $teams{$t});
        }
        return $table;
    }
    sub description {
        my $self = shift;
        return sprintf("%s %d. divisjon %d/%d", $self->league, $self->division, $self->year-1, $self->year);
    }
    sub TO_JSON {
        return shift->matches;
    }
};
package CurlingCalendar::Model::Data::Table {
    use Moo;
    
    has entries => (
        is => 'ro',
        default => sub { Mojo::Collection->new() },
        handles => [qw/each size TO_JSON/],
    );
};
package CurlingCalendar::Model::Data::Match {
    use Moo;

    has [qw/home away/] => (
        is => 'ro',
        required => 1,
    );
    has location => (
        is => 'ro',
        required => 1,
    );
    has time => (
        is => 'ro',
        required => 1,
    );

    has result => (
        is => 'ro',
        required => 0,
        predicate => 1,
    );
    sub uid {
        my $self = shift;
        my $season = shift;
        return sprintf("%s/%d/%d.division/%s-%s", 
            $season->league, $season->year, $season->division,
            $self->home, $self->away
        );
    }
    sub start {
        return shift->time->clone;
    }
    sub end {
        return shift->time->clone->add(hours => 2);
    }
    sub description {
        my $self = shift;
        my $season = shift;
        return sprintf("%s: %s - %s%s", $season->league, 
            $self->home, $self->away,
            ($self->result ? " (" . $self->result . ")" : "")
        );
    }

    sub is_team_playing {
        my ($self, $team) = @_;
        $team = lc($team);
        return (lc($self->home) eq $team or lc($self->away) eq $team);
    }
    sub TO_JSON {
        my $self = shift;
        return { %$self };
    }

};
1;

__END__
