package DashboardApp::Main;
use Mojo::Base 'Mojolicious::Controller';

use DashboardApp::Models::User;
use DashboardApp::Models::Ticket;
use Try::Tiny;

sub index {
  my $self = shift;
}

sub dashboard {
  my $c = shift;
  
  unless ( $c->session->{user_id} ) {
    return $c->render(json => { error => "You are not logged in!" });
  }
  
  ###
  
  my %tickets;
  my $columns = {
    1 => { name => "New tickets", search_query => "Status = 'new'", tickets => [] },
    2 => { name => "My tickets", search_query => "Owner = '__CurrentUser__' AND ( Status = 'new' OR Status = 'open')", tickets => [] },
    3 => { name => "Custom column", search_query => "", tickets => [] },
    4 => { name => "Some other column", search_query => "", tickets => [] },
  };
  
  ###
  
  my %seen_tickets;
  my $stored_columns = $c->session->{columns} || {};
  foreach my $column_id ( keys %$stored_columns ) {
    next unless ( $columns->{ $column_id } );
    foreach my $ticket_id ( @{ $stored_columns->{ $column_id } } ) {
      next if ( $seen_tickets{ $ticket_id } );
      push( @{ $columns->{ $column_id }->{tickets} }, $ticket_id );
      $seen_tickets{ $ticket_id } = 1;
    }
  }
  
  ###
  
  # Fetching tickets from RT
  
  foreach my $column_id ( keys %$columns ) {
    my $column = $columns->{$column_id};
    next unless ( $column->{search_query} );
    
    my $tickets;
    my $error = try {
      $tickets = DashboardApp::Models::Ticket::search_tickets( $column->{search_query} );
      return;
    } catch {
      return $_;    
    };
    
    $column->{tickets} = [];
    foreach my $ticket_id ( keys %$tickets ) {
      next if ( $seen_tickets{ $ticket_id } );
      push( @{ $column->{tickets} }, $ticket_id );
      $seen_tickets{ $ticket_id } = 1;
    }
    
    %tickets = ( %tickets, %$tickets );
    
    return $c->render( json => { error => $error } ) if ( $error );
  }
  
  ###
  
  $c->render(json => {
    status => "ok",
    tickets => \%tickets,
    columns => $columns
  });
}

sub login {
  my $c = shift;
  
  my $json = $c->req->json;
  
  unless ( DashboardApp::Models::User::check( $json->{login}, $json->{password} ) ) {
    return $c->render(json => { error => "Wrong login or password." });
  }
  
  $c->session({ user_id => $json->{login} });
  
  $c->render(json => { status => "ok" });
}

sub save_columns {
  my $c = shift;
  
  unless ( $c->session->{user_id} ) {
    return $c->render(json => { error => "You are not logged in!" });
  }
  
  my $json = $c->req->json;
  
  if ( ref( $json ) ne 'HASH' ) {
    return $c->render(json => { error => "Hash ref expected." });
  }
  
  my $stored_columns = $c->session->{columns} || {};
  
  foreach my $column_id ( keys %$json ) {
    my $column = $json->{ $column_id };
    if ( ref( $column ) ne "ARRAY" ) {
      return $c->render(json => { error => "Array ref expected." });
    }
    
    $stored_columns->{ $column_id } = $column;
  }
  
  $c->session->{columns} = $stored_columns;
  
  $c->render(json => { status => "ok" });
}

1;