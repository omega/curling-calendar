package CurlingCalendar::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

use Data::Printer;
use Data::ICal::DateTime;
use Data::ICal;
use Data::ICal::Entry::Event;

# This action will render a template

sub index {
    my $c = shift;
    $c->render();
}
sub division {
  my $c = shift;
  $c->curling->fetch_league(
      sub {
          my ($data) = @_;
          $c->app->log->debug($data->size . " events found");
          return $c->reply->not_found unless $data->size;

          my $ical = Data::ICal->new(
              rfc_strict => 1,
              calname => $data->description,
          );
          $data->each( sub {
                  my ($match) = @_;
                  my $event = Data::ICal::Entry::Event->new();
                  $event->start($match->start);
                  $event->end($match->end);
                  $event->add_properties(
                      uid => $match->uid($data),
                      summary => $match->description($data),
                      location => $match->location,
                  );

                  $ical->add_entry($event);
              }
          );
          $c->app->log->debug("created ical object?");
          $c->respond_to(
              html => { events => $data },
              json => { json => $data },
              ical => { text => $ical->as_string },

          );

      });
  $c->render_later;
}

1;
