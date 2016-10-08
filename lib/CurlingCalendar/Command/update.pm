package CurlingCalendar::Command::update;
use Mojo::Base 'Mojolicious::Command';

has description => 'Update curling times from excel-file';
has usage       => "Usage: APPLICATION update [FILE]\n";

use Spreadsheet::Read;
use Data::Dump::Color;
use DateTime;
use Path::Tiny;
use Mojo::JSON qw(encode_json);



sub run {
  my ($self, @args) = @_;

  my $path= $args[0];
  my $team_file = path($path)->child('Lagoversikt oack 2016 og 2017.xlsx');
  my $file = path($path)->child('Spilleoppsett 2016.xlsx');
  die "no such file" unless -f $file;

  my $teams = $self->get_teams($team_file);

  my $book = ReadData($file . "")->[1]->{cell};

  path('matchs_2017.json')->spew(
      encode_json([ $self->transform_to_matches($book, $teams) ])
  );
}

sub transform_to_matches {
    my ($self, $book, $teams) = @_;

    my @matches;
    my $base_dt = DateTime->new(year => 2016, month => 10, day => 10);

    my $count = scalar(@{ $book->[1] });
    foreach my $i (1 .. $count) {
        my $d = $book->[1]->[$i];
        next unless ($d and $d =~ m/^\d+$/);

        my $dt = $base_dt->clone()
            ->add(days => $book->[1]->[$i] - 42653)
            ->set_minute(30)
            ->set_hour( $book->[2]->[$i] > 0.8 ? 20 : 18)
        ;

        for my $venue (1..6) {
            my $h = $teams->{ $book->[$venue * 3    ]->[$i] };
            my $a = $teams->{ $book->[$venue * 3 + 2]->[$i] };
            my $l = $book->[$venue * 3]->[1];

            if ($h and $a) {
                push(@matches, {
                        time => $dt,
                        home => $h,
                        away => $a,
                        location => $l,
                    });
            }
        }
    }

    return @matches;
}

sub get_teams {
    my ($self, $file) = @_;

    my $teams = {};

    my $book = ReadData($file . "");

    foreach my $div (1..3) {
        my @b = grep($_ && /^\d{3}/, @{ $book->[$div]->{cell}->[1] });
        foreach my $t (@b) {
            my ($id) = ($t =~ m/(^\d{3})/);
            $teams->{$id} = $t;
        }
    }
    return $teams;
}

1;
