#!/usr/bin/perl -w
#
# tracwiki2mediawiki.pl - converts TracWiki format to MediaWiki format.
# Version 1.0, 14 November 2007
#
# Copyright (C) 2007 Uzi Cohen
#
#This tool is merely a  DRAFT version,a mini utility that can be used to convert Trac Wiki pages to MediaWiki format.
#The basis for this tool is php2mediawiki by Isaac Wilcox 
#Copyright (C) 2005 Isaac Wilcox
#http://www.iwilcox.me.uk/2005/07/php2mediawiki/
#php2mediawiki provided a convinient basis for this convertor and the monifications added to it 
#were introduced to support the conversion of the TracWiki format.
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
use strict;
use warnings;
use English;
use Carp;
use Data::Dumper;
use URI::Escape;
use POSIX qw(strftime);
 
# Make warnings into fatal, backtracing errors.
BEGIN { $SIG{__WARN__} = \&confess; }
 
#Some of the nice features originally provided by php2mediawiki, are not supported by this version,
#and it can now be used to convert single pages only.
# How to use the tool?
#-------------------------
# syntax:
# perl TracWiki2Mediawiki.pl <tracwiki_file.txt>
# Where the tracwiki_file.txt is a text file containing the tracwiki page 
#The file where the converted content will be stored will be named tracwiki_file.txt.after. 
# In order to get the TracWiki page content, goto the TracWiki page and click the edit button, copy and paste its content to the tracwiki_file.txt file, and run the convertion utility.
#
#Known issues
# - In tracwiki syntax, {{{ text }}} causes the text inside to be excluded from the wiki parsing, current version of the conversion tool does not support this exclude when it occurs over multiple lines... 
# - Tables' first line must start at the beginning of the line. 
# - A link to a file in the wiki, cannot be distinguished from a page link, thus all links would be treated as page links (rather than [[media:<filename>]]) 
# - CamalCase is not recognize as a link when converted to MediaWiki
# 
 
#The following are the comments as they appeared in  the original php2mediawiki
# Despite the long list of known issues below, the script does get most
# things right most of the time, so try it out before letting this list
# persuade you otherwise.  I've tried to list all the bugs regardless of
# size, for completeness.
#
# Known issues:
#  - Old-style PHPWiki syntax is unsupported unless it happens to match the
#    new-style markup.
#
#  - Only the OldStyleTable plugin is supported.  No other plugins work.
#    (I've patched my MediaWiki to include workalikes for 'backlinks' and
#    'unfoldsubpages', because my wiki uses them heavily; contact me if
#    you're interested.)
#
#  - PHPWiki page titles in BumpyCaps don't get spaces inserted (PHPWiki
#    would normally do this itself when rendering the page as HTML).  Not
#    sure I want to do this, either - some pages are meant to have spaces
#    inserted, and some aren't, and there's no way to tell.  Plus, without
#    extra work, all the internal Wiki links will break, and I can't be
#    bothered to do the extra work just yet.
#
#  - Characters in titles that PHPWiki allows but MediaWiki prohibits simply
#    cause the script to die, because my PHPWiki has "C++" at worst, which
#    is special-cased here.
#
#  - Clever links (InterWikiMaps?) like "Google:foo" aren't translated.
#    You can manually create templates that do the same thing - e.g., to
#    simulate an InterWikiMap of:
#      Google:foo => http://www.google.com/search?q=foo
#    you could create Template:Google, containing:
#      [http://www.google.com/search?q={{{1}}} Google:{{{1}}}]
#    and turn all Google:Foo into {{Google|Foo}} in this script.
#    (You might also want to fiddle with MAX_INCLUDE_REPEAT in Parser.php,
#    but I leave that to you.)
#    This is the solution I use, but currently you have to create the
#    templates (e.g. Template:Google) manually.  Templates could be created
#    automatically by this script if someone took the time to write the
#    code.
#    There's code here to change "Google:foo" into "{{Google|Foo}}", but it
#    depends on $is_zaks_own_wiki, and the list of supported mappings is
#    tiny (though it should be easy to add more).
#
#  - '_' in the middle of a word incorrectly gets italicized - effectively:
#    FOO_BAR_BAZ => FOO<I>BAR</I>BAZ.  This bites me in a surprising number
#    of places, but the regex fix is a little thorny.
#
#  - Tables:
#    - table cells starting with a lowercase letter 'o' are interfered with by
#      the bulleted list code, and break the table.
#    - tables whose first lines are indented don't get converted at all
#    - tables with an empty first cell go wrong
#    - old style tables don't honour < > ^ (looks easy to fix though)
#
#  - BumpyCaps with suppressing tildes (e.g. ~DontLinkThis) retain the
#    tildes; same for homedirs in URLs (e.g. http://host/~~user/).
#
#  - Anchors and links to anchors are broken.  MediaWiki mini-TOCs pretty
#    much make this irrelevent if you only use anchors for simulating TOCs
#    in your PHPWiki (as I did).
#
#  - The "=...=" (fixed-width font) PHPWiki markup conversion sometimes gets
#    overexcited, and turns "foo=bar,baz=quux" into
#    "foo<tt>bar,baz</tt>quux".
#
#  - Probably a fair few other things.  My PHPWiki really doesn't tax the
#    markup.
#
#
# On with the show.  Prerequisites:
#   1. Hopefully this goes without saying, but...you must have a working,
#      online PHPWiki and a working, online MediaWiki.
#
#   2. You must have accounts with the MySQL (or MySQL*s*) that host the PHP
#      and Media Wikis, and have relevant privileges.
#
#   3. You must have *NIX knowledge, and not be a fool.
#      I assume you're using *NIX, because I know nothing of Perl on Win32.
#      Patches for Win32 portability issues are of course welcome.
#
#   4. You must not expect the script to do /all/ the work for you.
#
 
# Turns on a few extra conversions that probably only Zak's wiki uses.
my $is_zaks_own_wiki = 0;
 
  my $infile_name = "";
  if ($#ARGV != 0) {
    print "usage: please specify a file name to convert\n";
    exit;
  }
  else {
   $infile_name = $ARGV[0];
  }
 
  my $page = get_page($infile_name);
 
  print "\n\n\n -> Converting page: $page->{title}\n";
  convert_markup($page);
 
  open(NEW_PAGE, ">$infile_name".".after");
  print NEW_PAGE "$page->{title}\n";
  print NEW_PAGE $page->{content};
  print NEW_PAGE "\n\n\n\n{{TracNotice|{{PAGENAME}}}}";
 
  close(NEW_PAGE);
 
exit(0);
 
# ID => "replacement text" mapping
my %deferred_substs;
 
# $pagehash get_page();
#
# Retrieve and return from a file the page's title and latest content in a
# hash.  
{
sub get_page {
  my ($file_name) = @_;
  my $pgcontent = "";
  my $pgtitle   = "";
  my $record    = "";
  my $page;
 
  open (ORIG_PAGE, "<".$file_name) || die "couldn't open input file! ($file_name)";
 
  $pgtitle = '';
  #if ( defined($pgtitle = <ORIG_PAGE>) ) {
    while ( defined($record = <ORIG_PAGE>) ) {
      $pgcontent .= $record;
    }
    $page = { title => $pgtitle, content => $pgcontent };
  #}
 
  close(ORIG_PAGE);
 
  return $page;
}
}
 
# void convert_markup($page);
#
# Convert $page (content, and maybe title) from PHPWiki to MediaWiki format as
# best we can.  Modifies $page in place.
sub convert_markup {
  my ($page) = @_;
  my $old_title = $page->{title};
 
  # http://en.wikipedia.org/wiki/Wikipedia:Naming_conventions_(technical_restrictions)
  # says that # + < > [ ] | { } are forbidden in MediaWiki page titles.  Only
  # pages I have here are variants on "C++", luckily for me, so I special-case
  # those and allow them.  Not so lucky for you...everything else causes script death.
  if ($page->{title} =~ /\+\+$/o) {
    $page->{title} =~ s/\+\+/_Plus_Plus/o;
  } elsif ($page->{title} =~ /\+\+/) {
    $page->{title} =~ s/\+\+/_Plus_Plus_/o;
  } elsif ($page->{title} =~ /^\//o
           || $page->{title} =~ /[]\[\{\}\<\>\#\+\|]/o) {
    # Starting with '/' is also unsupported.
    die("Can't yet handle page titles with funky chars in");
  }
  if ($page->{title} =~ / /o) {
    # MediaWiki doesn't expect to see embedded spaces in page titles in the
    # DB; the PHP layer will always turn a request for e.g. "Bumpy Caps"
    # into "Bumpy_Caps" before asking the DB.  So retitle such pages here.
    $page->{title} =~ s/ /_/go;
  }
  if ($page->{title} =~ /^[a-z]/o) {
    # Pages starting with small letters seem to break without this.
    # Again I think the PHP looks for IBook, not iBook.
    $page->{title} =~ s/^([a-z])/uc($1)/eo;
  }
 
  # Break the page up into lines.  This avoids having to special-case for \n in
  # the middle of things, and is apparently how PHPWiki looks at things.
  # Few PHPWiki constructs span >1 line.
  my @lines = split(/\n/, $page->{content});
 
  # Sort out verbatim sections early so that following substitutions just
  # see a placeholder and leave it alone.
  block_cvt_verbatim(\@lines);
 
  foreach my $line (@lines) {
    $line = cvt_linebreaks($line);
    $line = cvt_remove_exclamation_mark($line);
    $line = cvt_fixedwidth1($line);
    $line = cvt_para_open($line);
    $line = cvt_para_close($line);
    if ($is_zaks_own_wiki) {
      $line = cvt_unfolds($line);
      $line = cvt_backlinks($line);
    }
    # $line = cvt_plugins($line);
 
    # Apply in most specific --> least specific order to avoid applying an
    # overly generic conversion prematurely.  So, named external links
    # first, because they're more specific (http always in them).  Etc.
 
    #$line = cvt_wikiwords($line);
 
    $line = cvt_explicit_internal_links($line);
    $line = cvt_explicit_external_links($line);
 
    # InterWikiMaps (see note at top of file).  Has to precede WikiWords,
    # otherwise LocalFile:foo and Map:BumpyTarget get [[]]ified first.
    $line = cvt_interwikimaps($line);
 
 
 
    # It helps if this precedes cvt_lists, because '-' is a valid bulleted list
    # item marker.
    $line = cvt_horizontal_rules($line);
 
    # It helps if cvt_lists precedes bold, because '*' is a bit overloaded.
    $line = cvt_lists($line);    
    $line = cvt_underline($line);
    $line = cvt_strikethrough($line);
    $line = cvt_superscript($line);
    $line = cvt_subscript($line);
    $line = cvt_toc($line);
 
   #$line = cvt_bold_italics($line);
    #$line = cvt_bold($line);
    # old_bold should precede italics
    #$line = cvt_italics($line);  # same format - leave as is
 
    $line = cvt_fixedwidth2($line);
    # Headings must follow fixedwidth, because it produces '='
    $line = cvt_headings_trac($line); 
  }
 
  for (my $i = 0; $i < $#lines; $i++) {
    foreach my $block_cvt_sub (\( &block_cvt_new_style_tables, )) {
      my ($num_lines_to_remove, @new_content) = $block_cvt_sub->(\@lines, $i);
      if (defined($num_lines_to_remove)) {
        splice(@lines, $i, $num_lines_to_remove, @new_content);
        # Skip inserted lines, and subtract one because the for loop is about
        # to $i++ again.
        $i += $#new_content;
        # Arbitrary decision to only run one matching block converter on any
        # given section.
        last;
      }
    }
  }
 
  $page->{content} = join("\n", @lines);
  $page->{content} = apply_deferred_substs($page->{content});
  %deferred_substs = ();
 
  if ($is_zaks_own_wiki) {
    # HACK: sort links to pages called CategoryFoo, and sort any InterWikiMap
    # "Category:Foo" links...turn them all to [[Category:Foo]] and add a :
    # version so that the text still looks the same as it did.
    # By this point, Category links might look like any of:
    #  [[CategoryTools]]                    => [[Category:Tools]][[:Category:Tools]]
    #  [[Category:Tools]]                   => [[Category:Tools]][[:Category:Tools]]
    #  [[Category:WikiWord]] => same again
    #  Category:Tools                       => [[Category:Tools]]
    #  Category:[[WikiWord]] => [[Category:WikiWord]]
    # FIXME: use apply_deferred_substs again to avoid all this assertion mess
    foreach my $pat (qr/\[\[\s*Category([^]:]+)\]\]/,
                     qr/\[\[\s*Category:([^]]+)\]\]/,
         qr/(?:Category:(\w+))/,
         qr/(?:Category:\[\[(\w+)\]\])/) {
      while ($page->{content} =~ $pat) {
        my $id = defer_subst("[[Category:$1]][[:Category:$1]]");
        $page->{content} =~ s/$pat/{{{{$id}}}}/;
      }
    }
    $page->{content} = apply_deferred_substs($page->{content});
 
    # Another Zak-ism (might be useful to others too, but I'm sure there's a
    # neater way anyway).
    # Insert a template at content start to let users know that conversion is
    # temporary output.  Need original title for this.
    #
    # Need to turn spaces into %20 etc, otherwise e.g.:
    #   "http://foo/wiki/index.php/Old Page With Spaces"
    # won't link properly in MediaWiki.
    $old_title = uri_escape($old_title, " ");
    $page->{content} = "{{Conversion|$old_title}}<BR>\n" . $page->{content};
  }
}
 
sub block_cvt_new_style_tables {
  my ($lines, $i) = @_;
 
  # FIXME We don't recognise tables if the first line is indented, because the
  # converter breaks on them at the moment.
  #(see the bottom for rules for recognising tables)
  if ($lines->[$i] =~ /\s*\|\|.*/) {
    return convert_table($lines, $i);
  } else {
    return undef;
  }
}
 
# Turn <verbatim> into a MediaWiki indented-by-one section.  This block
# conversion is a little different to the rest in that it protects the
# wrapped content from any other conversions, line or block.  Thus, the
# arguments and return value are not like the other block_cvt_*(); it
# operates on @lines in place, and doesn't return anything.
#
# PHPWiki seems to want <verbatim> to start a line, and include trailing
# content on the same line.  It seems to want </verbatim> on a line on its
# own.
#
sub block_cvt_verbatim {
  my ($lines) = @_;
 
  for (my $i = 0; $i < $#{$lines}; $i++) {
    if ($lines->[$i] !~ /^<verbatim>(.*)(\s*)$/) {
      next;
    }
    my $cur_line = $i;
    my @new_content;
    # Gather content trailing after the opening tag, if any.
    if (defined($1)) {
      push(@new_content, " $1");
    }
    $cur_line++; # skip opening tag line
    while (defined($lines->[$cur_line]) && $lines->[$cur_line] !~ m|^</verbatim>$|) {
      push(@new_content, " " . $lines->[$cur_line]);
      $cur_line++;
    }
    # If we found an opening tag but there are no more closing tags, we're done.
    if (!defined($lines->[$cur_line])) {
      last;
    }
    my $id = defer_subst(join("\n", @new_content) . "\n");
    splice(@$lines, $i, $cur_line - $i + 1, ("{{{{$id}}}}"));
  }
}
 
# $id defer_subst($replacement_text);
#
# Add a deferred substitution to the list.  When you want to make sure that a
# substitution will not be susceptible to further changes, get an ID from this
# function and insert '{{{{id}}}}' instead of the replacement text.  Later,
# converter will find all '{{{{id}}}}'s and replace them with whatever you
# saved.  Useful to prevent e.g. BumpyCaps inside a URL being marked up.
{
my $next_deferred_subst_id;
sub defer_subst {
  my ($replacement_text) = @_;
  if (!defined($next_deferred_subst_id)) {
    $next_deferred_subst_id = 0;
  }
 
  $deferred_substs{$next_deferred_subst_id} = $replacement_text;
  return $next_deferred_subst_id++;
}
}
 
# void apply_deferred_substs($content);
#
# Apply all deferred substitutions to the given content (in place).
sub apply_deferred_substs {
  my ($content) = @_;
 
  $content =~ s/\{\{\{\{(\d+)\}\}\}\}/$deferred_substs{$1}/gx;
  return $content;
}
 
 
###############################################################################
# Markup conversion
###############################################################################
 
# Horizontal rules.
#
# This just protects HRs from further messing.
# Regex stolen from Block_hr (possibly changing leading whitespace semantics).
sub cvt_horizontal_rules {
  my ($line) = @_;
 
  if ($line =~ /^-{4,}\s*$/) {
    my $id = defer_subst($line);
    $line = "{{{{$id}}}}";
  }
  return $line;
}
 
# Headings
#  !!!text => ==text==     (section)
#  !!text  => ===text===   (subsection)
#  !text   => ====text==== (subsubsection)
#  See transform.php:wtm_headings().  Regex stolen from there.
sub cvt_headings_jsp {
  my ($line) = @_;
 
  if ($line =~ /^(!{1,3})[^!]/) {
    my $markup = '=' x (5 - length($1));
    $line =~ s/
      # remove the !s from start of line
      ^!{1,3}
      # and any leading whitespace on heading
      \s*
      # and capture the heading itself
      (.*)
      #Change it with
      /${markup}$1${markup}/x;
  }
  return $line;
}
 
# Headings
#  =text= => ==text==     (section)
#  ==text==  => ===text===   (subsection)
#  ===text===   => ====text==== (subsubsection)
#  See transform.php:wtm_headings().  Regex stolen from there.
sub cvt_headings_trac {
  my ($line) = @_;
  if ($line =~ /^(={1,3})[^=]+\1/) {
    my $markup = $1."=";
    $line =~ s/
      # remove the =s from start of line
      ^(={1,3})
      # and any leading whitespace on heading
      #\s*
      # and capture the heading itself
      ([^=]+)\1(.*)
      #Change it with
      /${markup}$2${markup}$3/x;
  }
  return $line;
}
 
# Unsupported single-line plugin calls.
#
# See transform.php:wtm_plugin().
#
# FIXME: handle multi-line calls (see Block_plugin).
# FIXME: do something with the plugins we can emulate.
sub cvt_plugins {
  my ($line) = @_;
 
  if ($line =~ /^<\?plugin\s.*\?>\s*$/) {
    # Hmm.  For now let's just save this chunk of stuff so it doesn't get
    # fiddled by other conversions.
    my $id = defer_subst($line);
    $line = "{{{{$id}}}}";
  }
  return $line;
}
 
# This one will only work if you've hacked your MediaWiki like Zak did.
# Contact me for the hack if you're interested.
sub cvt_backlinks {
  my ($line) = @_;
 
  # Only pay attention if there's a page=Category...
  if ($line =~ /^<\?plugin\s+BackLinks\s.*(?:page\s*=\s*Category([^\s]+)).*\?>\s*$/) {
    my $id = defer_subst("{{CATEGORYCONTENTS|$1}}");
    $line = "{{{{$id}}}}";
  }
  return $line;
}
 
# This one will only work if you've hacked your MediaWiki like Zak did.
# Contact me for the hack if you're interested.
sub cvt_unfolds {
  my ($line) = @_;
 
  # Only pay attention if there's a section=...
  if ($line =~ /^<\?plugin\s+UnfoldSubpages\s.*section\s*=\s*"?([^\s]+).*\?>\s*$/) {
    my $id = defer_subst("{{UNFOLD|$1}}");
    $line = "{{{{$id}}}}";
  }
  return $line;
}
 
# InterWikiMaps
#  i.e. [[Star(foo)]] --> {{Star|foo}}
# Very limited support - see notes at top of file.
sub cvt_interwikimaps {
  my ($line) = @_;
  my $supported_maps = join('|', qw/
    Google Star P360Doc
  /);
  my $pat = qr/
    # starts with [[
    \[\[
    # a recognised InterWikiMap mapping
    # $1 = mapping name
    ($supported_maps)
    # a '('
    \(
    # a parameter; I assume parameters can't contain parantases,
    # but maybe I'm wrong
    # $2 = parameter
    ([^)]+)
    # a ')'
    \)   
   # ends with ]]
    \]\]
  /x;
  my $template_name = '';
  my $param_list = '';
  while ($line =~ m/$pat/ox) {
    # Don't wanna let template invocations get converted any more.
    $template_name = $1;
    $param_list = $2;
    $param_list =~ s/,/\|/;
    my $id = defer_subst("{{$template_name|$param_list}}");
    $line =~ s/$pat/{{{{$id}}}}/;
  }
  return $line;
}
 
# WikiWords
#
# See $WikiNameRegexp in PHPWiki (occurs several times, not sure which if any
# is "the" regex).  Regex is hacked a /little/ here to document and capture.
sub cvt_wikiwords {
  my ($line) = @_;
  my $WikiWordRegex = qr/
    # must follow a non-alphanumeric char, or be first thing on the line
    # Also don't match if there's a preceding '~', because PHPWiki
    # suppresses markup in that case.
    (?<![~[:alnum:]])
    # match at least "FiFi"
    ((?:[[:upper:]][[:lower:]]+){2,})
    # and not followed by an alnum (hmm, think this is dirty...prev bit is
    # greedy, so think they meant [0-9A-Z] there)
    (?![[:alnum:]])/x;
 
  while ($line =~ m/$WikiWordRegex/ox) {
    # Don't wanna let WikiWords get converted any more...I don't think...
    # FIXME this defer might be unnecessary.
    my $id = defer_subst("[[$1]]");
    $line =~ s/$WikiWordRegex/{{{{$id}}}}/;
  }
  return $line;
}
 
# Explicit named  or  not named external links
#  [http://foo/ coolsite] => [http://foo/| coolsite]
#  [http://foo/] => [http://foo/]
sub cvt_explicit_external_links {
  my ($line) = @_;
  my $pat = qr/
    # Starts with a [
    \[    
    # then an http link (FIXME could be ftp, etc) containing non-link-ending
    # chars ($1 = http...)
    ((?:http|ftp|mailto)[^] ]+)
    # maybe some whitespace
    \s*
    # "coolsite" consists of non-link-ending, non-renaming chars
    # ($2 = coolsite)
    ([^]]*)
    # terminated by a ]
    \] 
  /x;
 
  while ($line =~ m/$pat/o) {
    my $id = 0;
    if ($2 eq "") {
      # Explicit anonymous external links
      #  [http://foo/] => http://foo/
      # These are modified to make images appear inline ([] in MW doesn't do this),
      # to make MW render them as the link address (these links appear as "[1]->"
      # otherwise) and to keep them safe from further messing by other conversions.
      # May need to treat images specially instead?
      #$id = defer_subst("[$1]");
 
      $id = defer_subst("$1");
    }
    else {
      $id = defer_subst("[$1 $2]");
    }
    $line =~ s/$pat/{{{{$id}}}}/x;
  }
  return $line;
}
 
# Explicit named  or  not named internal links
#  [wiki:foo coolpage] => [[foo| coolpage]]
#  [wiki:foo] => [[foo]]
sub cvt_explicit_internal_links {
  my ($line) = @_;
  my $pat = qr/
    # Starts with a [
    \[wiki:    
    # then an internal link containing non-link-ending
    # chars ($1 = internal link)
    ([^] ]+)
    # maybe some whitespace
    \s*
    # "coolpage" consists of non-link-ending, non-renaming chars
    # ($2 = coolpage)
    ([^]]*)
    # terminated by a ]
    \] 
  /x;
 
  while ($line =~ m/$pat/o) {
    my $id = 0;
    if ($2 eq "") {
      $id = defer_subst("[[$1]]");
    }
    else {
      $id = defer_subst("[[$1| $2]]");
    }
    $line =~ s/$pat/{{{{$id}}}}/x;
  }
  return $line;
}
 
# Bulleted lists
#
# A little more relaxed than Block_list, just because I hate that regex ;)
sub cvt_lists {
  my ($line) = @_;
  # Get a cup of tea.
  my $pat = qr/
    # Bullets must be first non-whitespace on line.
    # Capture the indentation so we can determine level later.
     ^(\ *)
    # About to encounter some list item marker, so start capturing so we can
    # tell later whether it was <OL> or <UL>.
     (
    # Any one of our 5 choices of bulleted list marker.
    # Now, the first 4 we'll ignore the other uses of, and always just see as
    # bullets.
      (1\.)|(a\.)|(i\.)
    # But '*' is annoying if you have a standalone line of bold text, which I
    # do, so the hairy negative lookahead from Block_list is copied here.
    # This basically considers * a bullet unless it looks like these:
    #   *foo, bar baz*
    #   *foo bar*
    #   *foobar*
    # cos that's probably meant to be bold.  But consider e.g. these to be
    # bullets:
    #   *foo bar*baz
    #   * foo bar*
    #   *foo bar *baz
      | \*
    # Not followed by:
       (?!
    ### One char of something (i.e. not space)
       \S
    ### Zero or more chars that aren't *s
       [^*]*
    ### The last of which must be a something (not space)
       (?<=\S)
    ### Then another *
       \*
    ### Followed by either space, or end of the line, i.e. not immediately
    ### followed by text.
       (?!\S)
    # End of "Not followed by"
      )
    # End of choice of bullets (captured).
    )
    # Possibly some spaces
    \ *
    # And followed by some content.
    (?=\S)
  /x;
 
  if ($line =~ /$pat/o) {
    # Work out nesting level. Two spaces make a new level.
    my $nest_level = (length($1) / 2) + 1;
    # If bullet used was UL, use '*', else use '#'.
    my $bullet;
    if ($2 eq '1.') {
      $bullet = '#';
    } 
    elsif ($2 eq 'a.') {
      $bullet = '#';
    }
    elsif ($2 eq 'i.') {
      $bullet = '#';
    }
    else {
      $bullet = '*';
    }
    my $wm_list_markup = $bullet x $nest_level;
    my $id = defer_subst("$wm_list_markup");
    $line =~ s/$pat/{{{{$id}}}}/;
  }
  return $line;
}
 
# Bold Italics
#  _*foo*_ => '''''foo'''''
sub cvt_bold_italics {
  my ($line) = @_;
  my $pat = qr/
    _\* ([^*]+) \*_
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/'''''$1'''''/g;
  }
  return $line;
}
 
# underline.
#  __foo__ => <u>foo</u>
sub cvt_underline {
  my ($line) = @_;
  my $pat = qr/
    __ (.+?) __
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/<u>$1<\/u>/g;
  }
  return $line;
}
 
 
# strikethrough.
#  ~~foo~~ => <a>foo</a>
sub cvt_strikethrough {
  my ($line) = @_;
  my $pat = qr/
    ~~ (.+?) ~~
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/<s>$1<\/s>/g;
  }
  return $line;
}
 
# subscript.
#  ,,foo,, => <sub>foo</sub>
sub cvt_subscript {
  my ($line) = @_;
  my $pat = qr/
    ,, (.+?) ,,
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/<sub>$1<\/sub>/g;
  }
  return $line;
}
 
# toc.
#  [[TOC(8_1/TOF/GMQA3R5)]] => __TOC__
sub cvt_toc {
  my ($line) = @_;
  my $pat = qr/
    \[\[TOC\( ([^)]+) \)\]\]
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/__TOC__/g;
  }
  return $line;
}
 
# superscript.
#  ^foo^ => <sup>foo</sup>
sub cvt_superscript {
  my ($line) = @_;
  my $pat = qr/
    \^ ([^^]+) \^
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/<sup>$1<\/sup>/g;
  }
  return $line;
}
# Bold
#  *foo* => '''foo'''
sub cvt_bold {
  my ($line) = @_;
  my $pat = qr/
    \* ([^*]+) \*
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/'''$1'''/g;
  }
  return $line;
}
 
# Italics
#  _foo_ => ''foo''
sub cvt_italics {
  my ($line) = @_;
  my $pat = qr/
    _ ([^_]+) _
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/''$1''/g;
  }
  return $line;
}
 
# Fixed width
#  !foo  => foo
sub cvt_remove_exclamation_mark {
  my ($line) = @_;
  my $pat = qr/
     \!( \w+ )
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/$1/g;
  }
  return $line;
}
 
# Fixed width
#  {{{foo}}} => <tt>foo</tt>
sub cvt_fixedwidth1 {
  my ($line) = @_;
  my $pre_str = '{{{';
  my $post_str = '}}}';
  my $pat = qr/
#  used to be:  ${pre_str}([^${post_str}]+)${post_str}   , changing it for:
     ${pre_str}(.+?)${post_str}
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/<tt>$1<\/tt>/g;
  }
  return $line;
}
 
# Fixed width
#  `foo` => <tt>foo</tt>
sub cvt_fixedwidth2 {
  my ($line) = @_;
  my $pat = qr/
    \`([^`]+)\`
  /x;
 
  while ($line =~ /$pat/o) {
    $line =~ s/$pat/<tt>$1<\/tt>/g;
  }
  return $line;
}
# Line breaks
#  [[BR]] => <br>
sub cvt_linebreaks {
  my ($line) = @_;
  if ($line =~ /\[\[BR\]\]/i) {
    $line =~ s/\[\[BR\]\]/<br>/iog;
  }
  return $line;
}
 
# paragraph
#  {{{ => <pre>
sub cvt_para_open {
  my ($line) = @_;
 
  if ($line =~ /{{{/) {
    $line =~ s/{{{/<pre>/og;
  }
  return $line;
}
 
# paragraph
#  {{{ => <pre>
sub cvt_para_close {
  my ($line) = @_;
 
  if ($line =~ /}}}/) {
    $line =~ s/}}}/<\/pre>/og;
  }
  return $line;
}
 
# HTML markup that's unsupported by MediaWiki:
# abbr acronym dfn kbd samp
#  FIXME
 
 
################## TABLES #####################################################
# PHPWiki syntax is a little hairy.  This parser requires 3 passes over the
# lines (!) to convert the syntax.  We could probably refactor this into less
# passes with a little effort, but I CBA.
 
# Top level; take in a reference to an array of lines and the index of a line
# on which a table starts, and return the number of lines used in the
# conversion and a replacement string containing the new content.
sub convert_table {
  my ($lines, $first_table_line) = @_;
 
  # Pass 1.  Get all the lines that make up the table.
  my @table_lines = collect_table($lines, $first_table_line);
  my $num_table_lines = @table_lines;
 
  # Pass 2.  Parse table into an IR.  This helps us handle rowspans and
  # colspans.
  # We might die if the table uses uneven indents.  Actually, we might die
  # anyway, so punt other errors.
  my $IR;
  eval {
    $IR = parse_table(@table_lines);
  };
  # If so, return the lines as they came, with markers.
  if ($@) {
      return ($num_table_lines, "''php2mediawiki failed to parse this table''", "''The table is included here unconverted:''", (map { s/^/ /; $_ } @table_lines), "''(End of failed conversion content)''");
  }
 
  # Pass 3.  Render the IR as MediaWiki table.
  return ($num_table_lines, render_table($IR));
}
 
# Pass 1:
# Collect up all the lines that make up a table, ready to parse the table.
# Return a list of lines.
sub collect_table {
  my ($lines, $first_table_line) = @_;
  my @table_lines;
 
  # FIXME see notes at bottom
  # We don't handle indented first lines!
  #
  # We can be sure that at least the next line is a table line, so grab at
  # least the first.
  $lines->[$first_table_line] =~ s/\s+$//;
  $lines->[$first_table_line] =~ s/^\s+//;
  push(@table_lines, $lines->[$first_table_line]);
  my $cur_line = $first_table_line + 1;
  while (exists($lines->[$cur_line])
         && $lines->[$cur_line] =~ /^\|\|.*/) {
    # Trim any trailing whitespace while we have the line in our clutches.
    $lines->[$cur_line] =~ s/\s+$//;
    push(@table_lines, $lines->[$cur_line]);
    $cur_line++;
  }
  # Trim trailing blank lines, as they're redundant and not really part of the
  # table.
  while ($table_lines[-1] =~ /^\s*$/) {
    pop(@table_lines);
  }
  return @table_lines;
}
 
# Pass 2:
# Parse a table into an IR.
# IR format is that each cell is either a cell hash ref like:
#  {
#    content => "foo",
#    rowspan => 5
#  }
# or a reference to a cell, which means the referring cell is actually spanned
# by the cell it refers to.
# The very last element of the returned IR will be the length of the longest
# row in the table, so that a renderer can sort out colspan.
sub parse_table {
  my (@table_lines) = @_;
  my $IR;
  my $max_row_length = 0;
 
  # Keep parsing rows while there are more input lines.
  while (@table_lines) {
    # Create an empty row in the IR.
    push(@$IR, []);
 
    # Get current line and one line of lookahead, and get indents for both.
    my $cur_line = shift(@table_lines);
 
    my $content;
    my $pat = qr/
              # look for a string that starts with ||
              \|\| 
              # capture the content untill the next || or the end of the line (non-greedy)
              (.*?) 
              # use look ahead to check if we have either || or end-of-line
              (?=(?:\|\| | $))
              /x;
    # Keep parsing cells until a new row is detected.
    while ($cur_line =~ /$pat/) {
      $content = $1;
      if ($cur_line !~ /^\|\|\s*$/  ) {
        $content =~ s/\|/\//; #change | char to / char.
 
        push(@{$IR->[-1]}, { content => $content, rowspan => 1 });
      }
      $cur_line =~ s/$pat//;
   }
   # Done with row.
   $max_row_length = (@{$IR->[-1]} > $max_row_length)
                     ? scalar(@{$IR->[-1]}) : $max_row_length;
  }
  push(@$IR, $max_row_length);
  return $IR;
}
 
# Hide all parsing of leading spaces; turn them all into indent levels, making
# sure that any indent level used is either the biggest yet or has been used
# before.
#
# This uses a Perl idiom to maintain a data structure which is private to a
# function and which which maintains state across calls.
# See the Camel, page 223.
#
# @cell_x is basically a hash.  For each defined element, the index corresponds
# to an indentation levels and the value corresponds to the X coordinate that
# cells with that indents should be assumed to be in.  This requires that
# indentation levels are used consistently throughout the table, which is not a
# constraint in PHPWiki (even if such tables do mess with your head).  It's not
# implemented as a hash because you'd have to sort() and max() a hash to find
# the largest indent so far :)
{
my @cell_x;
 
sub get_cell_x {
  my ($line) = @_;
 
  my $indent = 0;
  if ($line =~ /^(\s+)/) {
    $indent = length($1);
  }
  if (defined($cell_x[$indent])) {
    return $cell_x[$indent];
  } elsif ($indent > $#cell_x) {
    $cell_x[$indent] = (defined($cell_x[-1]) ? $cell_x[-1] + 1 : 0);
    return $cell_x[$indent];
  } else {
    die("PHPWiki table uses uneven indents");
  }
}
 
sub reset_cell_x {
  @cell_x = ();
}
}
 
sub update_rowspan {
  # $num_spanned_cols is the number of columns we need to update the rowspan
  # for in some cell.  As rowspans start from the left and must always follow
  # other rowspans, we know that the $num_spanned_cols cells are contiguous
  # starting from the LHS.
  my ($IR, $num_spanned_cols) = @_;
 
  foreach my $i (0 .. $num_spanned_cols-1) {
    if (ref($IR->[-2][$i]) eq 'HASH') {
      # If this is the first spanned cell, put a reference in to the spanning cell
      # so that any following spanned cells can easily find and update the
      # rowspan count.
      push(@{$IR->[-1]}, \$IR->[-2][$i]);
    } elsif (ref($IR->[-2][$i]) eq 'REF') {
      # If this is the second or subsequent spanned cell, then just
      # propagate the reference into this cell.
      push(@{$IR->[-1]}, $IR->[-2][$i]);
    }
    # And either way, update the rowspan by using the reference.  Which is
    # now a reference to a reference to a hash.  Had enough yet? :)
    ${$IR->[-1][$i]}->{rowspan}++;
  }
}
 
sub render_table {
  my ($IR) = @_;
  my $mw_table = "";
 
  # Grab the max row length early to not confuse loops later.
  my $max_row_length = pop(@$IR);
 
  $mw_table .= "{| border=1 class=\"simple\"\n";
  my $cell_start = "!";
 
  foreach my $y (0.. $#$IR) {
    foreach my $x (0.. $#{$IR->[$y]}) {
      my $cell = $IR->[$y][$x];
      next if ref($cell) ne 'HASH';
 
      my $cell_options = "";
 
      # If we're the last cell on the row, and we're not at column
      # $max_row_length, then this cell spans the remaining columns.
      if ($x == $#{$IR->[$y]}) {
        if ($x != $max_row_length-1) {
          $cell_options = "colspan=" . ($max_row_length - $x) . "|";
        }
      } 
 
      if ($cell->{rowspan} > 1) {
        $cell_options = "rowspan=$cell->{rowspan}|";
      }
      $mw_table .= $cell_start . $cell_options . $cell->{content} . "\n";
    }
    if ($y < $#$IR) {
      $mw_table .= "|- \n";
      $cell_start = "| ";
    }
  }
  $mw_table .= "|}\n";
 
  return $mw_table;
}
 
__END__
 
PHPWiki table markup parsing gotchas/notes/observations/assumptions.
 
A table starts with a --non-indented-- line ending in a pipe, followed by a ++
more++-indented line Course, the indented line can be as simple as this:
 
a |
 |  <-- interpreted as a cell containing a pipe
end
 
A table continues until:
  +++ - a less-indented line +++
 
  - A non-indented line that doesn't end with a pipe.  The unindented line
    "end" is used here to show when an example ends, and PHPWiki considers
    these to end the table.  Blank lines do not end tables:
 
a |
 b |
 
 c |
end
 
A row continues until:
 - indent level drops (start a new cell on next row)
 - the table ends
 
A cell continues until:
 - |\n<more indent> is encountered (start a new cell on same row)
   - collect this line's content, and exit with more_cells = 1
 - indent level drops (regardless of pipe)
   - immediately return with more_cells = 0, collecting nothing (do not pass Go)
 - a new cell with a follower (therefore ending in a pipe, and followed by a
   more indented line) is encountered
 - the table ends
 
The widest row in the table sets the number of columns.  Any row with less than
this amount will get rendered with the last cell in the row spanning the
remaining room.  This is the only way to cause a colspan.
 
Rowspan can be done across any subset of rows that is top-level or follows
another rowspan, with the caveat noted below.  Rowspan is caused by a drop in
indent level to less than zero.
 
If you don't end a cell's content line with a pipe, then all content up to the
next cell is placed in one cell, and that cell is forced to be the last cell on
the row.  This means in turn that rowspan can only be done with a table at
least 3 columns wide, because:
 
a |
 b
 c
end
 
is parsed as [ a | bc ].
 
All cells in a row except the last are bolded.
