package PerlSchool::Build;

use Moose;

use feature 'say';

use Template;
use Carp;

use PerlSchool::Schema;

has tt => (
  isa        => 'Template',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_tt {
  return Template->new(
    INCLUDE_PATH => [qw(in ttlib)],
    OUTPUT_PATH  => 'docs',
    WRAPPER      => 'page.tt',
  );
}

has schema => (
  isa        => 'PerlSchool::Schema',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_schema {
  return PerlSchool::Schema->get_schema;
}

has canonical_url => (
  isa     => 'Str',
  is      => 'ro',
  default => 'https://perlschool.com/',
);

has urls => (
  isa     => 'ArrayRef',
  is      => 'rw',
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    all_urls => 'elements',
    add_url  => 'push',
  },
);

has books => (
  isa        => 'ArrayRef',
  is         => 'rw',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_books => 'elements',
  },
);

sub _build_books {
  return [
    $_[0]->schema->resultset('Book')->search(
      undef, {
        order_by => { -desc => 'pubdate' },
      },
    )
  ];
}

has pages => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_pages => 'elements',
  },
);

sub _build_pages {
  return [qw( books about contact )];
}

sub run {
  my $self = shift;

  my @books = $self->all_books;

  $self->make_page(
    'index.html.tt', {
      feature   => $books[0],
      books     => [ @books[ 1 .. $#books ] ],
      canonical => $self->canonical_url,
    },
    'index.html',
  );

  for ( $self->all_pages ) {
    $self->make_page(
      "$_.html.tt", {
        books     => \@books,
        canonical => $self->canonical_url . "$_/",
      },
      "$_/index.html",
    );
  }

  for (@books) {
    $self->make_page(
      'book.html.tt', {
        feature   => $_,
        books     => \@books,
        canonical => $self->canonical_url . 'books/' . $_->slug . '/',
      },
      'books/' . $_->slug . '/index.html',
    );
  }

  $self->make_page(
    'sitemap.xml.tt', {
      urls => $self->urls,
    },
    'sitemap.xml',
  );

  return;
}

sub make_page {
  my $self = shift;
  my ( $template, $vars, $output ) = @_;

  $self->tt->process( $template, $vars, $output )
    or croak $self->tt->error;

  if ( exists $vars->{canonical} ) {
    $self->add_url( $vars->{canonical} );
  }

  return;
}

1;
