package Silex::Web::Donnenwa::Controller::List;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use Data::Pageset;
use POSIX;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Silex::Web::Donnenwa::Controller::List - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my %attr  = ( 'order_by' => { -desc => 'me.id' } );

    my $rs;
    my %cond    = ();
    my $page    = $c->req->params->{page};
    my $status  = $c->req->param("status") || $c->stash->{"status"} || '0'; #수정 필요

    $attr{page} = $page || 1;
    %cond       = ( status => $status ) if $status;
    $rs         = $c->model('DonDB')->resultset('Charge')->search(\%cond, \%attr);

    my $page_info =
    Data::Pageset->new(
        {
            ( map { $_ => $rs->pager->$_ } qw/entries_per_page total_entries current_page/ ),
            mode => "slide",
            pages_per_set => 10,
        }
    );

    $c->stash(
        lists   => [ $rs->all ],
        status  => $status,
        pageset => $page_info,
    );
}

sub write :Local :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->req->method eq 'POST') {
        my @messages;

        push @messages, 'amount is invaild' if ($c->req->params->{amount} !~ /^\d+$/);
        push @messages, 'title is required' unless ($c->req->params->{title});

        if (@messages) {
            $c->flash(
                    messages => @messages,
                    comment  => $c->req->params->{comment},
                    title    => $c->req->params->{title},
                    amount   => $c->req->params->{amount},
            );

            return $c->res->redirect($c->uri_for('/list/write'));
        }

        my $time = strftime "%Y-%m-%d %H:%M:%S", localtime; #적용 안해주면 GMT 기준으로 보임
        my %row  = (
            user       => $c->user->id,
            title      => $c->req->params->{title},
            comment    => $c->req->params->{content},
            amount     => $c->req->params->{amount},
            created_on => "$time",
            updated_on => "$time",
        );
        $c->model('DonDB')->resultset('Charge')->update_or_create(\%row);

        $c->res->redirect($c->uri_for('/list'));
    }
}

sub view :Local :CaptureArgs(1) {
    my ( $self, $c, $charge_id) = @_;

    my $charge = $c->model('DonDB')->resultset('Charge')->find($charge_id);

    $c->stash(
        charge     => $charge
    );
}

sub delete :Local :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    my @target_ids = split ',', $id;

    my $charge = $c->model('DonDB')->resultset('Charge')->search({ id => { -in => \@target_ids } })->delete_all;

    my $message;
    if ($charge) {        
        $c->flash->{messages} = '삭제되었습니다.';

    } else {
        $c->res->status(404);
        $c->flash->{messages} = '해당 청구항목이 없습니다.';
        $c->detach;
    }    

    $c->res->redirect($c->uri_for('/list'));
}

sub approval :Local :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    my @target_ids = split ',', $id;

    my $charge = $c->model('DonDB')->resultset('Charge')->search({ id => { -in
            => \@target_ids } })->update_all({ status => '2' });

    $c->stash->{status} = '2';
    $c->res->redirect($c->uri_for('/list'));
}

sub refuse :Local :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    my @target_ids = split ',', $id;

    my $charge = $c->model('DonDB')->resultset('Charge')->search({ id => { -in
            => \@target_ids } })->update_all({ status => '3' });

    $c->stash->{status} = '3';
    $c->res->redirect($c->uri_for('/list'));
}

sub edit :Local :CaptureArgs(1) {
    my ( $self, $c, $edit_id ) = @_;

    if ($c->req->method eq 'POST') {
        my @messages;

        push @messages, 'amount is invaild' if ($c->req->params->{amount} !~ /^\d+$/);
        push @messages, 'title is required' unless ($c->req->params->{title});

        if (@messages) {
            $c->flash(
                    messages => @messages,
                    comment  => $c->req->params->{comment},
                    title    => $c->req->params->{title},
                    amount   => $c->req->params->{amount},
            );

            return $c->res->redirect($c->uri_for("/list/view/$c->req->params->{charge_id}"));
        }

        my $time = strftime "%Y-%m-%d %H:%M:%S", localtime;
        my %row = (
            id         => $c->req->params->{charge_id},
            amount     => $c->req->params->{amount},
            user       => $c->req->params->{charge_user},
            title      => $c->req->params->{title},
            comment    => $c->req->params->{comment},
            updated_on => "$time",
        );
        $c->model('DonDB')->resultset('Charge')->update_or_create(\%row);

        $c->res->redirect($c->uri_for("/list/view/$row{id}"));
    }
    else {
        my $editer = $c->model('DonDB')->resultset('Charge')->find($edit_id);

        $c->stash(
            editer => $editer,
        );
    }
}

=head1 AUTHOR

meadow,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
