#!/usr/bin/perl

# LaTeXMathML.pl
# ==============
#
# This file is a reworking of Douglas Woodall's LaTeXMathML.js script,
# using Perl.  Every effort has been made to ensure that the Perl port
# will function in the same way and with the same reliability as the
# previous javascript version. This port was developed by Peter Williams
# for the University of Pittsburgh's Department of Chemical Engineering.
#
# Copyright (C) 2008  University of Pittsburgh
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# For more information, see the web page at
# http://pillars.che.pitt.edu/LaTeXMathML/
#
# Here are the header notices from LaTeXMathML.js:
#  
# LaTeXMathML.js
# ==============
# 
# This file ... is due to Douglas Woodall, June 2006.
# It contains JavaScript functions to convert (most simple) LaTeX
# math notation to Presentation MathML.  It was obtained by
# downloading the file ASCIIMathML.js from
#         http://www1.chapman.edu/~jipsen/mathml/asciimathdownload/
# and modifying it so that it carries out ONLY those conversions
# that would be carried out in LaTeX.  A description of the original
# file, with examples, can be found at
#         www1.chapman.edu/~jipsen/mathml/asciimath.html
#         ASCIIMathML: Math on the web for everyone
# 
# Here is the header notice from the original file:
# 
# ASCIIMathML.js
# ==============
# This file contains JavaScript functions to convert ASCII math notation
# to Presentation MathML. The conversion is done while the (X)HTML page
# loads, and should work with Firefox/Mozilla/Netscape 7+ and Internet
# Explorer 6+MathPlayer (http://www.dessci.com/en/products/mathplayer/).
# Just add the next line to your (X)HTML page with this file in the same folder:
# <script type="text/javascript" src="ASCIIMathML.js"></script>
# This is a convenient and inexpensive solution for authoring MathML.
# 
# Version 1.4.7 Dec 15, 2005, (c) Peter Jipsen http://www.chapman.edu/~jipsen
# Latest version at http://www.chapman.edu/~jipsen/mathml/ASCIIMathML.js
# For changes see http://www.chapman.edu/~jipsen/mathml/asciimathchanges.txt
# If you use it on a webpage, please send the URL to jipsen@chapman.edu
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License (at http://www.gnu.org/copyleft/gpl.html)
# for more details.
# 
# LaTeXMathML.js (ctd)
# ==============
# 
# The instructions for use are the same as for the original
# ASCIIMathML.js, except that of course the line you add to your
# file should be
# <script type="text/javascript" src="LaTeXMathML.js"></script>
# Or use absolute path names if the file is not in the same folder
# as your (X)HTML page.

#################################################################

use strict;
use XML::LibXML;
binmode(STDOUT, ":utf8");
my ($out, $document, %config, %debug, %AMcal, %AMfrk, %AMbbb, %AMsymbols, @AMnames);
#print "Running XML::LibXML version $XML::LibXML::VERSION\n";

# run from the command line
if (@ARGV) {
  &LaTeXMathML(@ARGV);
}

# run as a subroutine
sub LaTeXMathML {

# check through user configuration settings
%config = @_;

# check for required configuration elements
if (!$config{inputfile} && !$config{inputstream}) { print "Error: no inputfile selected!\n"; return; }
if (!$config{outputfile}) { print "Error: no outputfile selected!\n"; return; }

# check for default configuration elements
$config{AMmathml} = "http://www.w3.org/1998/Math/MathML" if (!$config{AMmathml});
$config{javascriptname} = "LaTeXMathML.js" if (!$config{javascriptname});
$config{mathstyle} = qq|<style type="text\/css">math { display: foreign; }<\/style>| if (!$config{mathstyle});

# $config{mathcolor} = ""  will inherit, or can be set to any other color
# $config{mathfontfamily} = ""  will inherit (works in IE), or can be set to any other family


# script-level configuration settings

%debug = ("byfragment", 0, "trace", 0,  "getsymbol", 0, "amsymbols", 0, "matrices", 0);

# character lists for Mozilla/Netscape fonts
%AMcal = ("A", "\x{EF35}", "B", "\x{212C}", "C", "\x{EF36}", "D", "\x{EF37}", "E", "\x{2130}", "F", "\x{2131}", "G", "\x{EF38}", "H", "\x{210B}", "I", "\x{2110}", "J", "\x{EF39}", "K", "\x{EF3A}", "L", "\x{2112}", "M", "\x{2133}", "N", "\x{EF3B}", "O", "\x{EF3C}", "P", "\x{EF3D}", "Q", "\x{EF3E}", "R", "\x{211B}", "S", "\x{EF3F}", "T", "\x{EF40}", "U", "\x{EF41}", "V", "\x{EF42}", "W", "\x{EF43}", "X", "\x{EF44}", "Y", "\x{EF45}", "Z", "\x{EF46}");
%AMfrk = ("A", "\x{EF5D}", "B", "\x{EF5E}", "C", "\x{212D}", "D", "\x{EF5F}", "E", "\x{EF60}", "F", "\x{EF61}", "G", "\x{EF62}", "H", "\x{210C}", "I", "\x{2111}", "J", "\x{EF63}", "K", "\x{EF64}", "L", "\x{EF65}", "M", "\x{EF66}", "N", "\x{EF67}", "O", "\x{EF68}", "P", "\x{EF69}", "Q", "\x{EF6A}", "R", "\x{211C}", "S", "\x{EF6B}", "T", "\x{EF6C}", "U", "\x{EF6D}", "V", "\x{EF6E}", "W", "\x{EF6F}", "X", "\x{EF70}", "Y", "\x{EF71}", "Z", "\x{2128}");
%AMbbb = ("A", "\x{EF8C}", "B", "\x{EF8D}", "C", "\x{2102}", "D", "\x{EF8E}", "E", "\x{EF8F}", "F", "\x{EF90}", "G", "\x{EF91}", "H", "\x{210D}", "I", "\x{EF92}", "J", "\x{EF93}", "K", "\x{EF94}", "L", "\x{EF95}", "M", "\x{EF96}", "N", "\x{2115}", "O", "\x{EF97}", "P", "\x{2119}", "Q", "\x{211A}", "R", "\x{211D}", "S", "\x{EF98}", "T", "\x{EF99}", "U", "\x{EF9A}", "V", "\x{EF9B}", "W", "\x{EF9C}", "X", "\x{EF9D}", "Y", "\x{EF9E}", "Z", "\x{2124}");

#################################################################

# prepare the AMsymbols hash:
my ($line, $linecontents, @linecontents, $el, $key, $val, $thisSymbol);

my @loadAMsymbols = split(/\n/, qq@
//Greek letters
{input:"\\alpha",	tag:"mi", output:"\x{03B1}", ttype:CONST},
{input:"\\beta",	tag:"mi", output:"\x{03B2}", ttype:CONST},
{input:"\\gamma",	tag:"mi", output:"\x{03B3}", ttype:CONST},
{input:"\\delta",	tag:"mi", output:"\x{03B4}", ttype:CONST},
{input:"\\epsilon",	tag:"mi", output:"\x{03B5}", ttype:CONST},
{input:"\\varepsilon",  tag:"mi", output:"\x{025B}", ttype:CONST},
{input:"\\zeta",	tag:"mi", output:"\x{03B6}", ttype:CONST},
{input:"\\eta",		tag:"mi", output:"\x{03B7}", ttype:CONST},
{input:"\\theta",	tag:"mi", output:"\x{03B8}", ttype:CONST},
{input:"\\vartheta",	tag:"mi", output:"\x{03D1}", ttype:CONST},
{input:"\\iota",	tag:"mi", output:"\x{03B9}", ttype:CONST},
{input:"\\kappa",	tag:"mi", output:"\x{03BA}", ttype:CONST},
{input:"\\lambda",	tag:"mi", output:"\x{03BB}", ttype:CONST},
{input:"\\mu",		tag:"mi", output:"\x{03BC}", ttype:CONST},
{input:"\\nu",		tag:"mi", output:"\x{03BD}", ttype:CONST},
{input:"\\xi",		tag:"mi", output:"\x{03BE}", ttype:CONST},
{input:"\\pi",		tag:"mi", output:"\x{03C0}", ttype:CONST},
{input:"\\varpi",	tag:"mi", output:"\x{03D6}", ttype:CONST},
{input:"\\rho",		tag:"mi", output:"\x{03C1}", ttype:CONST},
{input:"\\varrho",	tag:"mi", output:"\x{03F1}", ttype:CONST},
{input:"\\sigma",	tag:"mi", output:"\x{03C3}", ttype:CONST},
{input:"\\varsigma",	tag:"mi", output:"\x{03C2}", ttype:CONST},
{input:"\\tau",		tag:"mi", output:"\x{03C4}", ttype:CONST},
{input:"\\upsilon",	tag:"mi", output:"\x{03C5}", ttype:CONST},
{input:"\\phi",		tag:"mi", output:"\x{03C6}", ttype:CONST},
{input:"\\varphi",	tag:"mi", output:"\x{03D5}", ttype:CONST},
{input:"\\chi",		tag:"mi", output:"\x{03C7}", ttype:CONST},
{input:"\\psi",		tag:"mi", output:"\x{03C8}", ttype:CONST},
{input:"\\omega",	tag:"mi", output:"\x{03C9}", ttype:CONST},
{input:"\\Gamma",	tag:"mo", output:"\x{0393}", ttype:CONST},
{input:"\\Delta",	tag:"mo", output:"\x{0394}", ttype:CONST},
{input:"\\Theta",	tag:"mo", output:"\x{0398}", ttype:CONST},
{input:"\\Lambda",	tag:"mo", output:"\x{039B}", ttype:CONST},
{input:"\\Xi",		tag:"mo", output:"\x{039E}", ttype:CONST},
{input:"\\Pi",		tag:"mo", output:"\x{03A0}", ttype:CONST},
{input:"\\Sigma",	tag:"mo", output:"\x{03A3}", ttype:CONST},
{input:"\\Upsilon",	tag:"mo", output:"\x{03A5}", ttype:CONST},
{input:"\\Phi",		tag:"mo", output:"\x{03A6}", ttype:CONST},
{input:"\\Psi",		tag:"mo", output:"\x{03A8}", ttype:CONST},
{input:"\\Omega",	tag:"mo", output:"\x{03A9}", ttype:CONST},

//fractions
{input:"\\frac12",	tag:"mo", output:"\x{00BD}", ttype:CONST},
{input:"\\frac14",	tag:"mo", output:"\x{00BC}", ttype:CONST},
{input:"\\frac34",	tag:"mo", output:"\x{00BE}", ttype:CONST},
{input:"\\frac13",	tag:"mo", output:"\x{2153}", ttype:CONST},
{input:"\\frac23",	tag:"mo", output:"\x{2154}", ttype:CONST},
{input:"\\frac15",	tag:"mo", output:"\x{2155}", ttype:CONST},
{input:"\\frac25",	tag:"mo", output:"\x{2156}", ttype:CONST},
{input:"\\frac35",	tag:"mo", output:"\x{2157}", ttype:CONST},
{input:"\\frac45",	tag:"mo", output:"\x{2158}", ttype:CONST},
{input:"\\frac16",	tag:"mo", output:"\x{2159}", ttype:CONST},
{input:"\\frac56",	tag:"mo", output:"\x{215A}", ttype:CONST},
{input:"\\frac18",	tag:"mo", output:"\x{215B}", ttype:CONST},
{input:"\\frac38",	tag:"mo", output:"\x{215C}", ttype:CONST},
{input:"\\frac58",	tag:"mo", output:"\x{215D}", ttype:CONST},
{input:"\\frac78",	tag:"mo", output:"\x{215E}", ttype:CONST},

//binary operation symbols
{input:"\\pm",		tag:"mo", output:"\x{00B1}", ttype:CONST},
{input:"\\mp",		tag:"mo", output:"\x{2213}", ttype:CONST},
{input:"\\triangleleft",tag:"mo", output:"\x{22B2}", ttype:CONST},
{input:"\\triangleright",tag:"mo",output:"\x{22B3}", ttype:CONST},
{input:"\\cdot",	tag:"mo", output:"\x{22C5}", ttype:CONST},
{input:"\\star",	tag:"mo", output:"\x{22C6}", ttype:CONST},
{input:"\\ast",		tag:"mo", output:"\x{002A}", ttype:CONST},
{input:"\\times",	tag:"mo", output:"\x{00D7}", ttype:CONST},
{input:"\\div",		tag:"mo", output:"\x{00F7}", ttype:CONST},
{input:"\\circ",	tag:"mo", output:"\x{2218}", ttype:CONST},
//{input:"\\bullet",	  tag:"mo", output:"\x{2219}", ttype:CONST},
{input:"\\bullet",	tag:"mo", output:"\x{2022}", ttype:CONST},
{input:"\\oplus",	tag:"mo", output:"\x{2295}", ttype:CONST},
{input:"\\ominus",	tag:"mo", output:"\x{2296}", ttype:CONST},
{input:"\\otimes",	tag:"mo", output:"\x{2297}", ttype:CONST},
{input:"\\bigcirc",	tag:"mo", output:"\x{25CB}", ttype:CONST},
{input:"\\oslash",	tag:"mo", output:"\x{2298}", ttype:CONST},
{input:"\\odot",	tag:"mo", output:"\x{2299}", ttype:CONST},
{input:"\\land",	tag:"mo", output:"\x{2227}", ttype:CONST},
{input:"\\wedge",	tag:"mo", output:"\x{2227}", ttype:CONST},
{input:"\\lor",		tag:"mo", output:"\x{2228}", ttype:CONST},
{input:"\\vee",		tag:"mo", output:"\x{2228}", ttype:CONST},
{input:"\\cap",		tag:"mo", output:"\x{2229}", ttype:CONST},
{input:"\\cup",		tag:"mo", output:"\x{222A}", ttype:CONST},
{input:"\\sqcap",	tag:"mo", output:"\x{2293}", ttype:CONST},
{input:"\\sqcup",	tag:"mo", output:"\x{2294}", ttype:CONST},
{input:"\\uplus",	tag:"mo", output:"\x{228E}", ttype:CONST},
{input:"\\amalg",	tag:"mo", output:"\x{2210}", ttype:CONST},
{input:"\\bigtriangleup",tag:"mo",output:"\x{25B3}", ttype:CONST},
{input:"\\bigtriangledown",tag:"mo",output:"\x{25BD}", ttype:CONST},
{input:"\\dag",		tag:"mo", output:"\x{2020}", ttype:CONST},
{input:"\\dagger",	tag:"mo", output:"\x{2020}", ttype:CONST},
{input:"\\ddag",	tag:"mo", output:"\x{2021}", ttype:CONST},
{input:"\\ddagger",	tag:"mo", output:"\x{2021}", ttype:CONST},
{input:"\\lhd",		tag:"mo", output:"\x{22B2}", ttype:CONST},
{input:"\\rhd",		tag:"mo", output:"\x{22B3}", ttype:CONST},
{input:"\\unlhd",	tag:"mo", output:"\x{22B4}", ttype:CONST},
{input:"\\unrhd",	tag:"mo", output:"\x{22B5}", ttype:CONST},

//BIG Operators
{input:"\\sum",		tag:"mo", output:"\x{2211}", ttype:UNDEROVER},
{input:"\\prod",	tag:"mo", output:"\x{220F}", ttype:UNDEROVER},
{input:"\\bigcap",	tag:"mo", output:"\x{22C2}", ttype:UNDEROVER},
{input:"\\bigcup",	tag:"mo", output:"\x{22C3}", ttype:UNDEROVER},
{input:"\\bigwedge",	tag:"mo", output:"\x{22C0}", ttype:UNDEROVER},
{input:"\\bigvee",	tag:"mo", output:"\x{22C1}", ttype:UNDEROVER},
{input:"\\bigsqcap",	tag:"mo", output:"\x{2A05}", ttype:UNDEROVER},
{input:"\\bigsqcup",	tag:"mo", output:"\x{2A06}", ttype:UNDEROVER},
{input:"\\coprod",	tag:"mo", output:"\x{2210}", ttype:UNDEROVER},
{input:"\\bigoplus",	tag:"mo", output:"\x{2A01}", ttype:UNDEROVER},
{input:"\\bigotimes",	tag:"mo", output:"\x{2A02}", ttype:UNDEROVER},
{input:"\\bigodot",	tag:"mo", output:"\x{2A00}", ttype:UNDEROVER},
{input:"\\biguplus",	tag:"mo", output:"\x{2A04}", ttype:UNDEROVER},
{input:"\\int",		tag:"mo", output:"\x{222B}", ttype:CONST},
{input:"\\oint",	tag:"mo", output:"\x{222E}", ttype:CONST},

//binary relation symbols
{input:":=",		tag:"mo", output:":=",	   ttype:CONST},
{input:"\\lt",		tag:"mo", output:"<",	   ttype:CONST},
{input:"\\gt",		tag:"mo", output:">",	   ttype:CONST},
{input:"\\ne",		tag:"mo", output:"\x{2260}", ttype:CONST},
{input:"\\neq",		tag:"mo", output:"\x{2260}", ttype:CONST},
{input:"\\le",		tag:"mo", output:"\x{2264}", ttype:CONST},
{input:"\\leq",		tag:"mo", output:"\x{2264}", ttype:CONST},
{input:"\\leqslant",	tag:"mo", output:"\x{2264}", ttype:CONST},
{input:"\\ge",		tag:"mo", output:"\x{2265}", ttype:CONST},
{input:"\\geq",		tag:"mo", output:"\x{2265}", ttype:CONST},
{input:"\\geqslant",	tag:"mo", output:"\x{2265}", ttype:CONST},
{input:"\\equiv",	tag:"mo", output:"\x{2261}", ttype:CONST},
{input:"\\ll",		tag:"mo", output:"\x{226A}", ttype:CONST},
{input:"\\gg",		tag:"mo", output:"\x{226B}", ttype:CONST},
{input:"\\doteq",	tag:"mo", output:"\x{2250}", ttype:CONST},
{input:"\\prec",	tag:"mo", output:"\x{227A}", ttype:CONST},
{input:"\\succ",	tag:"mo", output:"\x{227B}", ttype:CONST},
{input:"\\preceq",	tag:"mo", output:"\x{227C}", ttype:CONST},
{input:"\\succeq",	tag:"mo", output:"\x{227D}", ttype:CONST},
{input:"\\subset",	tag:"mo", output:"\x{2282}", ttype:CONST},
{input:"\\supset",	tag:"mo", output:"\x{2283}", ttype:CONST},
{input:"\\subseteq",	tag:"mo", output:"\x{2286}", ttype:CONST},
{input:"\\supseteq",	tag:"mo", output:"\x{2287}", ttype:CONST},
{input:"\\sqsubset",	tag:"mo", output:"\x{228F}", ttype:CONST},
{input:"\\sqsupset",	tag:"mo", output:"\x{2290}", ttype:CONST},
{input:"\\sqsubseteq",  tag:"mo", output:"\x{2291}", ttype:CONST},
{input:"\\sqsupseteq",  tag:"mo", output:"\x{2292}", ttype:CONST},
{input:"\\sim",		tag:"mo", output:"\x{223C}", ttype:CONST},
{input:"\\simeq",	tag:"mo", output:"\x{2243}", ttype:CONST},
{input:"\\approx",	tag:"mo", output:"\x{2248}", ttype:CONST},
{input:"\\cong",	tag:"mo", output:"\x{2245}", ttype:CONST},
{input:"\\Join",	tag:"mo", output:"\x{22C8}", ttype:CONST},
{input:"\\bowtie",	tag:"mo", output:"\x{22C8}", ttype:CONST},
{input:"\\in",		tag:"mo", output:"\x{2208}", ttype:CONST},
{input:"\\ni",		tag:"mo", output:"\x{220B}", ttype:CONST},
{input:"\\owns",	tag:"mo", output:"\x{220B}", ttype:CONST},
{input:"\\propto",	tag:"mo", output:"\x{221D}", ttype:CONST},
{input:"\\vdash",	tag:"mo", output:"\x{22A2}", ttype:CONST},
{input:"\\dashv",	tag:"mo", output:"\x{22A3}", ttype:CONST},
{input:"\\models",	tag:"mo", output:"\x{22A8}", ttype:CONST},
{input:"\\perp",	tag:"mo", output:"\x{22A5}", ttype:CONST},
{input:"\\smile",	tag:"mo", output:"\x{2323}", ttype:CONST},
{input:"\\frown",	tag:"mo", output:"\x{2322}", ttype:CONST},
{input:"\\asymp",	tag:"mo", output:"\x{224D}", ttype:CONST},
{input:"\\notin",	tag:"mo", output:"\x{2209}", ttype:CONST},

//matrices
{input:"\\begin{eqnarray}",	output:"X",	ttype:MATRIX, invisible:true},
{input:"\\begin{array}",	output:"X",	ttype:MATRIX, invisible:true},
{input:"\\\\",			output:"}&{",	ttype:DEFINITION},
{input:"\\end{eqnarray}",	output:"}}",	ttype:DEFINITION},
{input:"\\end{array}",		output:"}}",	ttype:DEFINITION},

//grouping and literal brackets -- ieval is for IE
{input:"\\big",	   tag:"mo", output:"X", atval:"1.2", ieval:"2.2", ttype:BIG},
{input:"\\Big",	   tag:"mo", output:"X", atval:"1.6", ieval:"2.6", ttype:BIG},
{input:"\\bigg",   tag:"mo", output:"X", atval:"2.2", ieval:"3.2", ttype:BIG},
{input:"\\Bigg",   tag:"mo", output:"X", atval:"2.9", ieval:"3.9", ttype:BIG},
{input:"\\left",   tag:"mo", output:"X", ttype:LEFTBRACKET}, # PGW commented back in
{input:"\\right",  tag:"mo", output:"X", ttype:RIGHTBRACKET}, # PGW cmomented back in
{input:"{",	   output:"{", ttype:LEFTBRACKET,  invisible:true},
{input:"}",	   output:"}", ttype:RIGHTBRACKET, invisible:true},

{input:"(",	   tag:"mo", output:"(",      atval:"1", ttype:STRETCHY},
{input:"[",	   tag:"mo", output:"[",      atval:"1", ttype:STRETCHY},
{input:"\\lbrack", tag:"mo", output:"[",      atval:"1", ttype:STRETCHY},
{input:"\\{",	   tag:"mo", output:"{",      atval:"1", ttype:STRETCHY},
{input:"\\lbrace", tag:"mo", output:"{",      atval:"1", ttype:STRETCHY},
{input:"\\langle", tag:"mo", output:"\x{2329}", atval:"1", ttype:STRETCHY},
{input:"\\lfloor", tag:"mo", output:"\x{230A}", atval:"1", ttype:STRETCHY},
{input:"\\lceil",  tag:"mo", output:"\x{2308}", atval:"1", ttype:STRETCHY},

// rtag:"mi" causes space to be inserted before a following sin, cos, etc.
// (see function AMparseExpr() )
{input:")",	  tag:"mo",output:")",	    rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"]",	  tag:"mo",output:"]",	    rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"\\rbrack",tag:"mo",output:"]",	    rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"\\}",	  tag:"mo",output:"}",	    rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"\\rbrace",tag:"mo",output:"}",	    rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"\\rangle",tag:"mo",output:"\x{232A}", rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"\\rfloor",tag:"mo",output:"\x{230B}", rtag:"mi",atval:"1",ttype:STRETCHY},
{input:"\\rceil", tag:"mo",output:"\x{2309}", rtag:"mi",atval:"1",ttype:STRETCHY},

// "|", "\\|", "\\vert" and "\\Vert" modified later: lspace = rspace = 0em
{input:"|",		tag:"mo", output:"\x{2223}", atval:"1", ttype:STRETCHY},
{input:"\\|",		tag:"mo", output:"\x{2225}", atval:"1", ttype:STRETCHY},
{input:"\\vert",	tag:"mo", output:"\x{2223}", atval:"1", ttype:STRETCHY},
{input:"\\Vert",	tag:"mo", output:"\x{2225}", atval:"1", ttype:STRETCHY},
{input:"\\mid",		tag:"mo", output:"\x{2223}", atval:"1", ttype:STRETCHY},
{input:"\\parallel",	tag:"mo", output:"\x{2225}", atval:"1", ttype:STRETCHY},
{input:"/",		tag:"mo", output:"/",	atval:"1.01", ttype:STRETCHY},
{input:"\\backslash",	tag:"mo", output:"\x{2216}", atval:"1", ttype:STRETCHY},
{input:"\\setminus",	tag:"mo", output:"\\",	   ttype:CONST},

//miscellaneous symbols
{input:"\\!",	  tag:"mspace", atname:"width", atval:"-0.167em", ttype:SPACE},
{input:"\\,",	  tag:"mspace", atname:"width", atval:"0.167em", ttype:SPACE},
{input:"\\>",	  tag:"mspace", atname:"width", atval:"0.222em", ttype:SPACE},
{input:"\\:",	  tag:"mspace", atname:"width", atval:"0.222em", ttype:SPACE},
{input:"\\;",	  tag:"mspace", atname:"width", atval:"0.278em", ttype:SPACE},
{input:"~",	  tag:"mspace", atname:"width", atval:"0.333em", ttype:SPACE},
{input:"\\quad",  tag:"mspace", atname:"width", atval:"1em", ttype:SPACE},
{input:"\\qquad", tag:"mspace", atname:"width", atval:"2em", ttype:SPACE},
{input:"{}",		tag:"mo", output:"\x{200B}", ttype:CONST}, # zero-width, PGW commented back in
{input:"\\prime",	tag:"mo", output:"\x{2032}", ttype:CONST},
{input:"'",		tag:"mo", output:"\x{02B9}", ttype:CONST},
{input:"''",		tag:"mo", output:"\x{02BA}", ttype:CONST},
{input:"'''",		tag:"mo", output:"\x{2034}", ttype:CONST},
{input:"''''",		tag:"mo", output:"\x{2057}", ttype:CONST},
{input:"\\ldots",	tag:"mo", output:"\x{2026}", ttype:CONST},
{input:"\\cdots",	tag:"mo", output:"\x{22EF}", ttype:CONST},
{input:"\\vdots",	tag:"mo", output:"\x{22EE}", ttype:CONST},
{input:"\\ddots",	tag:"mo", output:"\x{22F1}", ttype:CONST},
{input:"\\forall",	tag:"mo", output:"\x{2200}", ttype:CONST},
{input:"\\exists",	tag:"mo", output:"\x{2203}", ttype:CONST},
{input:"\\Re",		tag:"mo", output:"\x{211C}", ttype:CONST},
{input:"\\Im",		tag:"mo", output:"\x{2111}", ttype:CONST},
{input:"\\aleph",	tag:"mo", output:"\x{2135}", ttype:CONST},
{input:"\\hbar",	tag:"mo", output:"\x{210F}", ttype:CONST},
{input:"\\ell",		tag:"mo", output:"\x{2113}", ttype:CONST},
{input:"\\wp",		tag:"mo", output:"\x{2118}", ttype:CONST},
{input:"\\emptyset",	tag:"mo", output:"\x{2205}", ttype:CONST},
{input:"\\infty",	tag:"mo", output:"\x{221E}", ttype:CONST},
{input:"\\surd",	tag:"mo", output:"\\sqrt{}", ttype:DEFINITION}, # requires {}, above
{input:"\\partial",	tag:"mo", output:"\x{2202}", ttype:CONST},
{input:"\\nabla",	tag:"mo", output:"\x{2207}", ttype:CONST},
{input:"\\triangle",	tag:"mo", output:"\x{25B3}", ttype:CONST},
{input:"\\therefore",	tag:"mo", output:"\x{2234}", ttype:CONST},
{input:"\\angle",	tag:"mo", output:"\x{2220}", ttype:CONST},
//{input:"\\\\ ",	  tag:"mo", output:"\x{00A0}", ttype:CONST}, # commented out by DRW, segfaults
{input:"\\diamond",	tag:"mo", output:"\x{22C4}", ttype:CONST},
//{input:"\\Diamond",	  tag:"mo", output:"\x{25CA}", ttype:CONST},
{input:"\\Diamond",	tag:"mo", output:"\x{25C7}", ttype:CONST},
{input:"\\neg",		tag:"mo", output:"\x{00AC}", ttype:CONST},
{input:"\\lnot",	tag:"mo", output:"\x{00AC}", ttype:CONST},
{input:"\\bot",		tag:"mo", output:"\x{22A5}", ttype:CONST},
{input:"\\top",		tag:"mo", output:"\x{22A4}", ttype:CONST},
{input:"\\square",	tag:"mo", output:"\x{25AB}", ttype:CONST},
{input:"\\Box",		tag:"mo", output:"\x{25A1}", ttype:CONST},
{input:"\\wr",		tag:"mo", output:"\x{2240}", ttype:CONST},

//standard functions
//Note UNDEROVER *must* have tag:"mo" to work properly
{input:"\\arccos", tag:"mi", output:"arccos", ttype:UNARY, func:true},
{input:"\\arcsin", tag:"mi", output:"arcsin", ttype:UNARY, func:true},
{input:"\\arctan", tag:"mi", output:"arctan", ttype:UNARY, func:true},
{input:"\\arg",	   tag:"mi", output:"arg",    ttype:UNARY, func:true},
{input:"\\cos",	   tag:"mi", output:"cos",    ttype:UNARY, func:true},
{input:"\\cosh",   tag:"mi", output:"cosh",   ttype:UNARY, func:true},
{input:"\\cot",	   tag:"mi", output:"cot",    ttype:UNARY, func:true},
{input:"\\coth",   tag:"mi", output:"coth",   ttype:UNARY, func:true},
{input:"\\csc",	   tag:"mi", output:"csc",    ttype:UNARY, func:true},
{input:"\\deg",	   tag:"mi", output:"deg",    ttype:UNARY, func:true},
{input:"\\det",	   tag:"mi", output:"det",    ttype:UNARY, func:true},
{input:"\\dim",	   tag:"mi", output:"dim",    ttype:UNARY, func:true}, //CONST?
{input:"\\exp",	   tag:"mi", output:"exp",    ttype:UNARY, func:true},
{input:"\\gcd",	   tag:"mi", output:"gcd",    ttype:UNARY, func:true}, //CONST?
{input:"\\hom",	   tag:"mi", output:"hom",    ttype:UNARY, func:true},
{input:"\\inf",	   tag:"mo", output:"inf",    ttype:UNDEROVER},
{input:"\\ker",	   tag:"mi", output:"ker",    ttype:UNARY, func:true},
{input:"\\lg",	   tag:"mi", output:"lg",     ttype:UNARY, func:true},
{input:"\\lim",	   tag:"mo", output:"lim",    ttype:UNDEROVER},
{input:"\\liminf", tag:"mo", output:"liminf", ttype:UNDEROVER},
{input:"\\limsup", tag:"mo", output:"limsup", ttype:UNDEROVER},
{input:"\\ln",	   tag:"mi", output:"ln",     ttype:UNARY, func:true},
{input:"\\log",	   tag:"mi", output:"log",    ttype:UNARY, func:true},
{input:"\\max",	   tag:"mo", output:"max",    ttype:UNDEROVER},
{input:"\\min",	   tag:"mo", output:"min",    ttype:UNDEROVER},
{input:"\\Pr",	   tag:"mi", output:"Pr",     ttype:UNARY, func:true},
{input:"\\sec",	   tag:"mi", output:"sec",    ttype:UNARY, func:true},
{input:"\\sin",	   tag:"mi", output:"sin",    ttype:UNARY, func:true},
{input:"\\sinh",   tag:"mi", output:"sinh",   ttype:UNARY, func:true},
{input:"\\sup",	   tag:"mo", output:"sup",    ttype:UNDEROVER},
{input:"\\tan",	   tag:"mi", output:"tan",    ttype:UNARY, func:true},
{input:"\\tanh",   tag:"mi", output:"tanh",   ttype:UNARY, func:true},

//arrows
{input:"\\gets",		tag:"mo", output:"\x{2190}", ttype:CONST},
{input:"\\leftarrow",		tag:"mo", output:"\x{2190}", ttype:CONST},
{input:"\\to",			tag:"mo", output:"\x{2192}", ttype:CONST},
{input:"\\rightarrow",		tag:"mo", output:"\x{2192}", ttype:CONST},
{input:"\\leftrightarrow",	tag:"mo", output:"\x{2194}", ttype:CONST},
{input:"\\uparrow",		tag:"mo", output:"\x{2191}", ttype:CONST},
{input:"\\downarrow",		tag:"mo", output:"\x{2193}", ttype:CONST},
{input:"\\updownarrow",		tag:"mo", output:"\x{2195}", ttype:CONST},
{input:"\\Leftarrow",		tag:"mo", output:"\x{21D0}", ttype:CONST},
{input:"\\Rightarrow",		tag:"mo", output:"\x{21D2}", ttype:CONST},
{input:"\\Leftrightarrow",	tag:"mo", output:"\x{21D4}", ttype:CONST},
{input:"\\iff", tag:"mo", output:"~\\Longleftrightarrow~", ttype:DEFINITION},
{input:"\\Uparrow",		tag:"mo", output:"\x{21D1}", ttype:CONST},
{input:"\\Downarrow",		tag:"mo", output:"\x{21D3}", ttype:CONST},
{input:"\\Updownarrow",		tag:"mo", output:"\x{21D5}", ttype:CONST},
{input:"\\mapsto",		tag:"mo", output:"\x{21A6}", ttype:CONST},
{input:"\\longleftarrow",	tag:"mo", output:"\x{2190}", ttype:LONG},
{input:"\\longrightarrow",	tag:"mo", output:"\x{2192}", ttype:LONG},
{input:"\\longleftrightarrow",	tag:"mo", output:"\x{2194}", ttype:LONG},
{input:"\\Longleftarrow",	tag:"mo", output:"\x{21D0}", ttype:LONG},
{input:"\\Longrightarrow",	tag:"mo", output:"\x{21D2}", ttype:LONG},
{input:"\\Longleftrightarrow",  tag:"mo", output:"\x{21D4}", ttype:LONG},
{input:"\\longmapsto",		tag:"mo", output:"\x{21A6}", ttype:CONST}, # disaster if LONG

//commands with argument
{input:"_",		tag:"msub",  output:"_",	ttype:INFIX}, # AMsub
{input:"^",		tag:"msup",  output:"^",	ttype:INFIX}, # AMsup
{input:"\\sqrt",	tag:"msqrt", output:"sqrt",	ttype:UNARY}, # AMsqrt
{input:"\\root",	tag:"mroot", output:"root",	ttype:BINARY}, # AMroot
{input:"\\frac",	tag:"mfrac", output:"/",	ttype:BINARY}, # AMfrac
{input:"\\atop",	tag:"mfrac", output:"",		ttype:INFIX}, # AMatop
{input:"\\choose",	tag:"mfrac", output:"",		ttype:INFIX}, # AMchoose
{input:"\\stackrel",	tag:"mover", output:"stackrel", ttype:BINARY}, # AMover
{input:"\\mathrm",	tag:"mtext", output:"text",	ttype:TEXT}, # AMtext
{input:"\\mbox",	tag:"mtext", output:"mbox",	ttype:TEXT}, # AMmbox

//diacritical marks
//{input:"\\acute",	  tag:"mover",  output:"\x{0317}", ttype:UNARY, acc:true},
//{input:"\\acute",	  tag:"mover",  output:"\x{0301}", ttype:UNARY, acc:true},
{input:"\\acute",	tag:"mover",  output:"\x{00B4}", ttype:UNARY, acc:true},
//{input:"\\grave",	  tag:"mover",  output:"\x{0300}", ttype:UNARY, acc:true},
//{input:"\\grave",	  tag:"mover",  output:"\x{0316}", ttype:UNARY, acc:true},
{input:"\\grave",	tag:"mover",  output:"\x{0060}", ttype:UNARY, acc:true},
{input:"\\breve",	tag:"mover",  output:"\x{02D8}", ttype:UNARY, acc:true},
{input:"\\check",	tag:"mover",  output:"\x{02C7}", ttype:UNARY, acc:true},
{input:"\\dot",		tag:"mover",  output:".",      ttype:UNARY, acc:true},
//{input:"\\ddot",	  tag:"mover",  output:"\x{00A8}", ttype:UNARY, acc:true},
{input:"\\ddot",	tag:"mover",  output:"..",     ttype:UNARY, acc:true},
{input:"\\mathring",	tag:"mover",  output:"\x{00B0}", ttype:UNARY, acc:true},
{input:"\\vec",		tag:"mover",  output:"\x{20D7}", ttype:UNARY, acc:true},
{input:"\\overrightarrow",tag:"mover",output:"\x{20D7}", ttype:UNARY, acc:true},
{input:"\\overleftarrow",tag:"mover", output:"\x{20D6}", ttype:UNARY, acc:true},
{input:"\\hat",		tag:"mover",  output:"\x{005E}", ttype:UNARY, acc:true},
{input:"\\widehat",	tag:"mover",  output:"\x{0302}", ttype:UNARY, acc:true},
//{input:"\\tilde",	  tag:"mover",  output:"\x{0303}", ttype:UNARY, acc:true},
{input:"\\tilde",	tag:"mover",  output:"~",      ttype:UNARY, acc:true},
{input:"\\widetilde",	tag:"mover",  output:"\x{02DC}", ttype:UNARY, acc:true},
{input:"\\bar",		tag:"mover",  output:"\x{203E}", ttype:UNARY, acc:true},
{input:"\\overbrace",	tag:"mover",  output:"\x{23B4}", ttype:UNARY, acc:true}, // should be FE37 - in chinese font set
{input:"\\overbracket", tag:"mover",  output:"\x{23B4}", ttype:UNARY, acc:true}, // added by PGW
{input:"\\overline",	tag:"mover",  output:"\x{00AF}", ttype:UNARY, acc:true},
{input:"\\underbrace",  tag:"munder", output:"\x{23B5}", ttype:UNARY, acc:true}, // should be FE38 - in chinese font set
{input:"\\underbracket",tag:"munder", output:"\x{23B5}", ttype:UNARY, acc:true}, // added by PGW
//{input:"underline",	tag:"munder", output:"\x{0332}", ttype:UNARY, acc:true},
{input:"\\underline",	tag:"munder", output:"\x{00AF}", ttype:UNARY, acc:true},

//typestyles and fonts
{input:"\\displaystyle",tag:"mstyle",atname:"displaystyle",atval:"true", ttype:UNARY},
{input:"\\textstyle",tag:"mstyle",atname:"displaystyle",atval:"false", ttype:UNARY},
{input:"\\scriptstyle",tag:"mstyle",atname:"scriptlevel",atval:"1", ttype:UNARY},
{input:"\\scriptscriptstyle",tag:"mstyle",atname:"scriptlevel",atval:"2", ttype:UNARY},
{input:"\\textrm", tag:"mstyle", output:"\\mathrm", ttype:DEFINITION},
{input:"\\mathbf", tag:"mstyle", atname:"mathvariant", atval:"bold", ttype:UNARY},
{input:"\\textbf", tag:"mstyle", atname:"mathvariant", atval:"bold", ttype:UNARY},
{input:"\\mathit", tag:"mstyle", atname:"mathvariant", atval:"italic", ttype:UNARY},
{input:"\\textit", tag:"mstyle", atname:"mathvariant", atval:"italic", ttype:UNARY},
{input:"\\mathtt", tag:"mstyle", atname:"mathvariant", atval:"monospace", ttype:UNARY},
{input:"\\texttt", tag:"mstyle", atname:"mathvariant", atval:"monospace", ttype:UNARY},
{input:"\\mathsf", tag:"mstyle", atname:"mathvariant", atval:"sans-serif", ttype:UNARY},
{input:"\\mathbb", tag:"mstyle", atname:"mathvariant", atval:"double-struck", ttype:UNARY, codes:AMbbb},
{input:"\\mathcal",tag:"mstyle", atname:"mathvariant", atval:"script", ttype:UNARY, codes:AMcal},
{input:"\\mathfrak",tag:"mstyle",atname:"mathvariant", atval:"fraktur",ttype:UNARY, codes:AMfrk},

@);

# Commented out by DRW to prevent 1/2 turning into a 2-line fraction
# AMdiv   = {input:"/",	 tag:"mfrac", output:"/",    ttype:INFIX},

# Commented out by DRW so that " prints literally in equations
# AMquote = {input:"\"",	 tag:"mtext", output:"mbox", ttype:TEXT};

# Handling for additional symbols ("newcommand")
# LaTeXMathML.pl can be extended with additional symbols, using the following format:
# $config{newsymbols} = qq|\nle	0x2270
# \nge	0x2271|;
# Four-digit hexadecimal unicode characters (with a leading 0x) are accepted, and delimited 
# from the custom latex command names (such as \nle and \nge) with tabs and newlines.
my @sym = split(/\n/, $config{newsymbols});
foreach $line (@sym) {
  chomp($line); next unless $line =~ /\w/;
  my @symline = split(/\t/, $line);
  $symline[1] = oct($symline[1]) if $symline[1] =~ /^0/;
  $symline[1] = chr($symline[1]);
  push(@loadAMsymbols, qq|{input:"$symline[0]", tag:"mo", output:"$symline[1]", ttype:DEFINITION},|);
}

foreach $line (@loadAMsymbols) {
  next if ($line =~ /^\/\// || $line =~ /^\#/);
  if ($line =~ /\{(.*)\}\,/) {
    $linecontents = $1;
    print "$linecontents\n" if $debug{amsymbols};

    # split the contents of the line on commas (except the escaped one)
    $linecontents =~ s/([^\\])\,/$1 \,/g;
    @linecontents = split(/\s\,/, $linecontents);
    foreach $el (@linecontents) {

      # split each part of the line into key: value pairs and store them
      if ($el =~ /([^\:\n]+)\:\"([^\"\n]+)\"/) {
        ($key, $val) = ($1, $2);
        $key =~ s/^\s+//;
        $val =~ s/\\/\\\\/g; # double escape characters
        print "$key: $val\t" if $debug{amsymbols};
        $thisSymbol = $val if ($key eq "input");
        $AMsymbols{$thisSymbol}{$key} = "$val" unless ($key eq "input");

      } elsif ($el =~ /([^\:\n]+)\:([\w]+)/) {
        ($key, $val) = ($1, $2);
        $key =~ s/^\s+//;
        print "$key: $val\t" if $debug{amsymbols};
        $thisSymbol = $val if ($key eq "input");
        $AMsymbols{$thisSymbol}{$key} = "$val" unless ($key eq "input");

      }
    }

    if ($debug{amsymbols}) {
      print "\nchecking $thisSymbol...\t";
      foreach $key (keys %{$AMsymbols{$thisSymbol}}) {
        print "$key: $AMsymbols{$thisSymbol}{$key}\t";
      } print "\n";
    }

  }
}

# AMinitSymbols: prepare sorted list of symbol names as AMnames
# not sure if this sorts the same way as javascript does
@AMnames = keys %AMsymbols;
@AMnames = sort @AMnames;
print "check AMnames: @AMnames\n" if $debug{amsymbols};

#################################################################

# read input file
my $parser = XML::LibXML->new();
if ($config{inputfile}) {
  $document = $parser->parse_file("$config{inputfile}");
} elsif ($config{inputstream}) {
  $document = $parser->parse_string("$config{inputstream}");
} else {
  print "No document input could be located!  Exiting.\n";
  return;
}
print "document: $document\n" if $debug{byfragment};

$out = eval( my @AllContainers = $document->getElementsByTagName("*") );

# find body tag and run AMProcessNodeR
foreach my $node (@AllContainers) {
  my $name = $node->nodeName;
  if ($name eq "body") {
    # skipping over AMprocessNode (included spanclassAM, innerHTML and a little isIE handling)
    &AMprocessNodeR($node, "");
    last;
  }
}

print "-------------------------------------------------------------------------------------\n" if $debug{byfragment};

# put XML document back together, and write output
my $output = $document->toString;

# replace the javascript call with style settings for math
if ($output =~ /(\<script[^\>]*src\=\"[^\"]*$config{javascriptname}\"[^\>]*\>\s*\<\/script\>)/i) {
  $output =~ s/(\<script[^\>]*src\=\"[^\"]*$config{javascriptname}\"[^\>]*\>\s*\<\/script\>)/$config{mathstyle}/i;
}

open (OUT, ">$config{outputfile}");
binmode(OUT, ":utf8");
print OUT $output;
close(OUT);

print "Done\n" if $debug{byfragment};
return;
}
1;

#################################################################

# process each node, identifying sections of LatexMathML
sub AMprocessNodeR {
  my ($n, $pre) = @_;
  my $name = $n->nodeName;

  # move on to process node's children, unless this is a math node
  if ($n->hasChildNodes()) {
    unless ($name eq "math") {
      my @childnodes = $n->childNodes;
      foreach my $child (@childnodes) {
        &AMprocessNodeR($child, $pre."  ");
      }
    }

  # if the node has no children, process it
  } else {

    # check node type and parent node's name
    my $type = $n->nodeType;
    my $parentnode = $n->parentNode;
    my $parentname = lc($parentnode->nodeName);
    if ($type != 8 && $parentname ne "form" && $parentname ne "textarea" && $parentname ne "pre") {
      my $str = $n->nodeValue;
      if (defined($str) && $str ne "") {

        # clean up whitespace
        $str =~ s/ +/ /g;
        $str =~ s/\s+\n/\n/g;

        # DELIMITERS:
        if ($str =~ /[^\\]\$/) {
          if ($debug{byfragment}) {
            print "-------------------------------------------------------------------------------------\n";
            print "process $name node ($parentname):\n";
            print "$str\n";
          }

          # pad unescaped dollar signs with a preceding space, split string on these
          $str =~ s/([^\\])\$/$1 \$/g;
          $str =~ s/^\$/ \$/g;

          my @arr = split(/\s\$/, $str);
          foreach my $el (0 .. @arr - 1) { $arr[$el] =~ s/\\\$/\$/g; }

          # we aren't concerned with the actual display of MathML here
          # ignoring variables: checkForMathML, AMnoMathML, notifyIfNoMathML, alertIfNoMathML
          # ignoring functions: AMisMathMLavailable, AMnoMathMLNote

          # process the node as an array
          print "passing from AMprocessNodeR to AMstrarr2docFrag\n" if $debug{trace};
          my $frg = &AMstrarr2docFrag($type, @arr);
          print "returning to AMprocessNodeR from AMstrarr2docFrag\n" if $debug{trace};

          $n = $parentnode->replaceChild($frg,$n);

          #if ($debug{byfragment}) {
          #  print "-------------------------------------------\n";
          #  my $str2 = join("\$", @arr); print "$str2\n";
          #}
        } else {

          # fix escaped dollar signs, in any section which doesn't contain math
          $str =~ s/\\\$/\$/g;

          #if ($debug{byfragment}) {
          #  print "-------------------------------------------------------------------------------------\n";
          #  print "process $name node ($parentname) without math:\n";
          #  print "$str\n";
          #}

          $n->setData($str);
        }
      }
    }
  }
}

#################################################################

# work through string array, process every other section for MathML and output newFrags
sub AMstrarr2docFrag {
  my ($type, @arr) = @_;
  my $newFrag = $document->createDocumentFragment();
  my $expr = 0;

  # process LatexMathML sections of the document
  foreach my $i (@arr) {
    print "-------------------------------------------\n" if $debug{byfragment};

    # process the math sections and add them
    if ($expr) {
      print "process chunk: $i\n" if $debug{byfragment};
      print "passing from AMstrarr2docFrag to AMparseMath, with string: $i\n" if $debug{trace};
      $newFrag->appendChild(&AMparseMath($i));
      print "returning to AMstrarr2docFrag from AMparseMath\n" if $debug{trace};
      $expr = 0;

    # add the non-math sections as-is
    } else {
      print "skip chunk: $i\n" if $debug{byfragment};

      # separate handling of arri for comment type nodes, not currently set up
      if ($type == 8) {
        print "WARNING: WE DID GET A NODE TYPE OF EIGHT!\n";
      }

      my $spanel = $document->createElementNS("http://www.w3.org/1999/xhtml","span");
      $newFrag->appendChild($spanel->appendChild($document->createTextNode($i)));
      $expr = 1;
    }
  }
  return $newFrag;
}

#################################################################

# set up a MathML node, handling display settings
sub AMparseMath {
  my ($str) = @_; $str =~ s/^\s+//;
  my $node = $document->createElement("mstyle");

  $node->setAttribute("mathcolor", $config{mathcolor}) if ($config{mathcolor} ne "");
  $node->setAttribute("fontfamily", $config{mathfontfamily}) if ($config{mathfontfamily} ne "");

  # parse this section for math expressions, create a complete <math> node
  $str =~ s/^\s+//g;
  print "passing from AMparseMath to AMparseExpr, with string: $str\n" if $debug{trace};
  my ($parsedExpr) = &AMparseExpr($str, 0, 0);
  print "returning to AMparseMath from AMparseExpr\n" if $debug{trace};
  $node->appendChild($parsedExpr);
  $node = &AMcreateMmlNode("math", $node, 1);

  # skipping: showasciiformulaonhover

  if ($config{mathfontfamily} ne "" && $config{mathfontfamily} ne "serif") {
    my $fnode = $document->createElement("font");
    $fnode->setAttribute("face", $config{mathfontfamily});
    $fnode->appendChild($node);
    return $fnode;
  }
  return $node;
}

#################################################################

# parse a section of the total string array for math expressions
# AMparseExpr handles things in substrings, checking for rightbrackets and matrices
# passes everything else on to AMparseIexpr
sub AMparseExpr {
  my ($str, $rightbracket, $matrix) = @_;
  my ($symbol, $s_output, $s_type, $s_tag, $node, $tag, $i);
  my $newFrag = $document->createDocumentFragment();

  do {
    $str = &AMremoveCharsAndBlanks($str, 0);

    print "passing from AMparseExpr to AMparseIexpr, with string: $str\n" if $debug{trace};
    ($node, $str, $tag) = &AMparseIexpr($str);
    print "returning to AMparseExpr from AMparseIexpr, with $node / $str / $tag\n" if $debug{trace};

    ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
    print "got symbol in AMparseExpr: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};

    if (defined($node) && $node ne "") {

      # add space before \sin in 2\sin x or x\sin x (and all standard functions?)
      if (($tag eq "mn" || $tag eq "mi") && defined($symbol) && $symbol ne "" && $AMsymbols{$symbol}{func} eq "true") {
        my $space = $document->createElement("mspace");
        $space->setAttribute("width", "0.167em");
        $node = &AMcreateMmlNode("mrow", $node, 1);
        $node->appendChild($space);
      }

      $newFrag->appendChild($node);
    }

  } while ($s_type ne "RIGHTBRACKET" && defined($symbol) && $symbol ne "");

  $tag = "";


  if ($s_type eq "RIGHTBRACKET") {

    if ($symbol eq "\\\\right") { # makes the next symbol (brace, bracket, etc) a right-hand one
      $str = &AMremoveCharsAndBlanks($str, length($symbol) - 1);
      ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
      print "got symbol in AMparseExpr/RightBracket: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
      $AMsymbols{$symbol}{invisible} = "true" if ($symbol eq ".");
      $tag = $AMsymbols{$symbol}{rtag} if (defined($symbol) && $symbol ne "");
    }

    if (defined($symbol) && $symbol ne "") {
      my $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
      $str = &AMremoveCharsAndBlanks($str, $snip); # ready to return
    }


    # MATRIX handling
    my @len = $newFrag->childNodes;
    my $len = @len; # number of newFrag's childNodes
    if ($matrix && $len > 1 && $len[$len-1]->nodeName eq "mrow" && $len[$len-2]->nodeName eq "mo" && $len[$len-2]->firstChild->nodeValue eq "&") {
      print "actually processing this matrix symbol\n" if $debug{matrices};
      my ($i, $j, $row, $frag, $fragis);
      my %pos = ();

      my @mlen = $newFrag->childNodes;
      my $m = @mlen; # number of newFrag's childNodes
      print "recheck number of children: $m\n" if $debug{matrices};

      # check every other childNode from newFrag
      for ($i = 0; $i < $m; $i+=2) {
      print "checking child $i: " . $len[$i]->nodeName . "\n" if $debug{matrices};

        # check each of that node's childnodes (newFrag's grandchildren)
        $node = $len[$i];
        my @jlen = $node->childNodes;
        for ($j=0; $j < @jlen; $j++) {

          # if the value of the first great-grandchild is &, mark it
          my $firstgreatgrand = $jlen[$j]->firstChild;
          print "checking grandchild $j: great-grandchild 1: " . $firstgreatgrand->nodeValue . "\n" if ($firstgreatgrand && $debug{matrices});
          if ($firstgreatgrand && $firstgreatgrand->nodeValue eq "&") {
            $pos{$i}{$j} = 1; # switched the handling of this to not use $k
            print "found an ampersand\n" if $debug{matrices};
          }

        } # end of first j loop
      } # end of first i loop

      my $table = $document->createDocumentFragment();

      # check every other childNode from newFrag
      for ($i=0; $i < $m; $i+=2) {
        print "recheck child $i:" . $len[$i]->nodeName . "\n" if $debug{matrices};
        $row = $document->createDocumentFragment();
        $frag = $document->createDocumentFragment(); $fragis = 0;

        # take newFrag's first child...
        $node = $newFrag->firstChild; # <mrow> -&-&...&-&- </mrow>
        print "check node: $node\n" if $debug{matrices};

        # check each of that child's children...
        my @nlen = $node->childNodes;
        for ($j=0; $j<@nlen; $j++) {
        print "recheck grandchild: $j: " . $nlen[$j]->nodeName . "\n" if $debug{matrices};

          if ($pos{$i}{$j} == 1) {
            print "matched ampersand\n" if $debug{matrices};
            $node->removeChild($node->firstChild); # remove &
            unless ($fragis) { # fix by PGW
              my $space = $document->createElement("mspace");
              $frag->appendChild($space);
              $fragis = 1;
            }
            $row->appendChild(&AMcreateMmlNode("mtd", $frag, 1)) if $fragis;
          } else {
            $frag->appendChild($node->firstChild);
            $fragis = 1;
          }

        } # end of second j loop

        $row->appendChild(&AMcreateMmlNode("mtd", $frag, 1));

        # double check how many children are on newFrag and trim two at a time
        my @nfc = $newFrag->childNodes;
        if (@nfc > 2) {
          $newFrag->removeChild($newFrag->firstChild); # remove <mrow> </mrow>
          $newFrag->removeChild($newFrag->firstChild); # remove <mo>&</mo>
        }

        $table->appendChild(&AMcreateMmlNode("mtr", $row, 1));

      } # end of second i loop

      return ($table, $str);

    } # end to the doubled if matrix block


    unless ($AMsymbols{$symbol}{invisible} eq "true") {
      $node = &AMcreateMmlNode("mo", $document->createTextNode($s_output), 1);
      $newFrag->appendChild($node);
    }
  }

  # return the complete segment that we have processed, $newFrag
  return ($newFrag, $str, $tag);

}

#################################################################

# continue parsing a section of the total string array for math expressions
# AMparseIexpr passes things on to AMparseSexpr, and checks for INFIX tags
sub AMparseIexpr {
  my ($str) = @_;
  my($symbol, $s_output, $s_type, $s_tag, $node, $tag, $n_underover, $node2);

  $str = &AMremoveCharsAndBlanks($str, 0);

  # store previous symbol for INFIX handling
  my ($sym1, $sym1_output, $sym1_type, $sym1_tag) = &AMgetSymbol($str);
  print "got symbol in AMparseIexpr/sym1: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};

  print "passing from AMparseIexpr to AMparseSexpr, with string: $str\n" if $debug{trace};
  ($node, $str, $tag, $n_underover) = &AMparseSexpr($str);
  print "returning to AMparseIexpr from AMparseSexpr, with $node / $str / $tag / $n_underover\n" if $debug{trace};

  ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
  print "got symbol in AMparseIexpr: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};

  if ($s_type eq "INFIX") {
    my $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
    $str = &AMremoveCharsAndBlanks($str, $snip);

    print "passing from AMparseIexpr/Infix to AMparseSexpr, with string: $str\n" if $debug{trace};
    ($node2, $str, $tag) = &AMparseSexpr($str);
    print "returning to AMparseIexpr/Infix from AMparseSexpr, with $node2 / $str / $tag\n" if $debug{trace};

    # show box in place of missing argument
    $node2 = &AMcreateMmlNode("mo", $document->createTextNode("\x{25A1}"), 1) if (!defined($node2) || $node2 eq "");

    if ($symbol eq "_" || $symbol eq "^") {
      my ($sym2) = &AMgetSymbol($str); # get next symbol
      print "got symbol in AMparseIexpr/Infix: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
      $tag = ""; # no space between x^2 and a following sin, cos, etc.
      my $underover = 1 if ($sym1_type eq "UNDEROVER" || $n_underover); # this is for \underbrace and \overbrace
      if ($symbol eq "_" && $sym2 eq "^") {
        $str = &AMremoveCharsAndBlanks($str, length($sym2));
        my($res2);
        print "passing from AMparseIexpr/Infix2 to AMparseSexpr, with string: $str\n" if $debug{trace};
        ($res2, $str, $tag) = &AMparseSexpr($str); # $tag: leave space between x_1^2 and a following sin etc.
        print "returning to AMparseIexpr/Infix2 from AMparseSexpr, with $res2 / $str / $tag\n" if $debug{trace};
        $node = &AMcreateMmlNode("munderover", $node, 1) if $underover;
        $node = &AMcreateMmlNode("msubsup", $node, 1) unless $underover;
        $node->appendChild($node2);
        $node->appendChild($res2);
      } elsif ($symbol eq "_") {
        $node = &AMcreateMmlNode("munder", $node, 1) if $underover;
        $node = &AMcreateMmlNode("msub", $node, 1) unless $underover;
        $node->appendChild($node2);
      } else {
        $node = &AMcreateMmlNode("mover", $node, 1) if $underover;
        $node = &AMcreateMmlNode("msup", $node, 1) unless $underover;
        $node->appendChild($node2);
      }
      $node = &AMcreateMmlNode("mrow", $node, 1); # so sum does not stretch

    } else {
      $node = &AMcreateMmlNode($s_tag, $node, 1);
      if ($symbol eq "\\\\atop" || $symbol eq "\\\\choose") {
        $node->setAttribute("linethickness", "0ex");
      }
      $node->appendChild($node2);
      if ($symbol eq "\\\\choose") {
        $node = &AMcreateMmlNode("mfenced", $node, 1);
      }
    }
  }

  return ($node, $str, $tag);
}

#################################################################

# continue parsing a section of the total string array for math expressions
# AMparseSexpr processes most of the content and returns:
# a node, what's left of $str after what was processed, and the node's tag
sub AMparseSexpr {
  my ($str) = @_;
  my ($symbol, $s_output, $s_type, $s_tag, $node, $snip, @result, @result2);
  my $newFrag = $document->createDocumentFragment();
  $str = &AMremoveCharsAndBlanks($str, 0);

  ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
  print "got symbol in AMparseSexpr: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};


  if (!defined($symbol) || $symbol eq "" || $s_type eq "RIGHTBRACKET") {
    return ("", $str, "");


  } elsif ($s_type eq "DEFINITION") {
    $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);

    # skip any empty matrix rows (added by PGW)
    if ($symbol eq "\\\\\\\\") {
      my(@empty_rows) = ("\\\\", "\\end{array}", "\\end{eqnarray}");
      my ($mcheck, $mchecksymbol, $mchecksoutput);
      do {
        $mcheck = &AMremoveCharsAndBlanks($str, $snip);
        ($mchecksymbol, $mchecksoutput) = &AMgetSymbol($mcheck);
        if (grep(/^$mchecksymbol$/, @empty_rows)) { # next symbol tells us this is an empty row
          $str = $mcheck;  $symbol = $mchecksymbol;  $s_output = $mchecksoutput;
          $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
        }
      } while (grep(/^$mchecksymbol$/, @empty_rows));
    }

    $s_output =~ s/\\\\/\\/g;
    $str = $s_output . &AMremoveCharsAndBlanks($str, $snip);
    ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
    print "got symbol in AMparseSexpr/Definition: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
    if (!defined($symbol) || $symbol eq "" || $AMsymbols{$symbol}{ttype} eq "RIGHTBRACKET") {
      return ("", $str, "");
    }
  }


  $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
  $str = &AMremoveCharsAndBlanks($str, $snip);


  if ($s_type eq "SPACE") {
    $node = $document->createElement($s_tag);
    $node->setAttribute($AMsymbols{$symbol}{atname}, $AMsymbols{$symbol}{atval});
    return($node, $str, $s_tag);


  } elsif ($s_type eq "UNDEROVER") {
    # stripped isIE handling
    return (&AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1), $str, $s_tag);


  } elsif ($s_type eq "CONST") {
    # stripped isIE handling
    $s_output = "\\" if ($s_output eq "\\\\"); # correct double backslashes as output
    return (&AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1), $str, $s_tag);


  } elsif ($s_type eq "LONG") {
    $node = &AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1);
    $node->setAttribute("minsize","1.5");
    $node->setAttribute("maxsize","1.5");
    $node = &AMcreateMmlNode("mover", $node, 1);
    $node->appendChild($document->createElement("mspace"));
    return ($node, $str, $s_tag);


  } elsif ($s_type eq "STRETCHY") { # added by DRW
    # stripped isIE handling
    $node = &AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1);

    if ($symbol eq "|" || $symbol eq "\\\\vert" || $symbol eq "\\\\|" || $symbol eq "\\\\Vert") {
      $node->setAttribute("lspace", "0em");
      $node->setAttribute("rspace", "0em");
    }

    $node->setAttribute("maxsize", $AMsymbols{$symbol}{atval}); # don't allow to stretch here

    if (defined($AMsymbols{$symbol}{rtag}) && $AMsymbols{$symbol}{rtag} ne "") {
      return ($node, $str, $AMsymbols{$symbol}{rtag});
    } else {
      return ($node, $str, $s_tag);
    }


  } elsif ($s_type eq "BIG") {
    my $atval = $AMsymbols{$symbol}{atval};
    # stripped isIE handling

    ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
    print "got symbol in AMparseSexpr/Big: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
    return("", $str, "") if (!defined($symbol) || $symbol eq "");

    $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
    $str = &AMremoveCharsAndBlanks($str, $snip);

    $node = &AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1);
    # stripped isIE handling
    $node->setAttribute("minsize", $atval);
    $node->setAttribute("maxsize", $atval);
    return($node, $str, $s_tag);


  } elsif ($s_type eq "LEFTBRACKET") {
    if ($symbol eq "\\\\left") { # makes the next symbol (brace, bracket, etc) a left-hand one
      ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
      print "got symbol in AMparseSexpr/LeftBracket: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
      $AMsymbols{$symbol}{invisible} = "true" if ($symbol eq ".");
      if (defined($symbol) && $symbol ne "") {
        $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
        $str = &AMremoveCharsAndBlanks($str, $snip);
      }
    }

    # recurse down into nested brackets
    print "passing from AMparseSexpr/LeftBracket to AMparseExpr, with string: $str\n" if $debug{trace};
    @result = &AMparseExpr($str, 1, 0);
    print "returning to AMparseSexpr/LeftBracket from AMparseExpr, with $result[0] / $result[1] / $result[2] \n" if $debug{trace};

    if (!defined($symbol) || $symbol eq "" || $AMsymbols{$symbol}{invisible} eq "true") {
      $node = &AMcreateMmlNode("mrow", $result[0], 0);
    } else {
      $node = &AMcreateMmlNode("mo", $document->createTextNode($s_output), 1);
      $node = &AMcreateMmlNode("mrow", $node, 1);
      $node->appendChild($result[0]);
    }

    return ($node, $result[1], $result[2]);


  } elsif ($s_type eq "MATRIX") {
    if ($symbol eq "\\\\begin{array}") {

      # gather mask information for array
      my $mask = "";
      ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
      print "got symbol in AMparseSexpr/Matrix1: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
      $str = &AMremoveCharsAndBlanks($str, 0);
      if (!defined($symbol) || $symbol eq "") {
        $mask = "l";
      } else {
        $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
        $str = &AMremoveCharsAndBlanks($str, $snip);
        if ($symbol ne "{") {
          $mask = "l";
        } else {
          do {
            ($symbol, $s_output, $s_type, $s_tag) = &AMgetSymbol($str);
            print "got symbol in AMparseSexpr/Matrix2: $symbol output: $s_output type: $s_type tagst: $s_tag\n" if $debug{getsymbol};
            if (defined($symbol) && $symbol ne "") {
              $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
              $str = &AMremoveCharsAndBlanks($str, $snip);
              $mask .= $symbol if ($symbol ne "}");
            }
          } while (defined($symbol) && $symbol ne "" && $symbol ne "}");
        }
      }

      print "passing from AMparseSexpr/Matrix_array to AMparseExpr, with string: {$str\n" if $debug{trace};
      @result = &AMparseExpr("{".$str, 1, 1);
      print "returning to AMparseSexpr/Matrix_array to AMparseExpr, with  $result[0] / $result[1] / $result[2]\n" if $debug{trace};

      $node = &AMcreateMmlNode("mtable", $result[0], 1);

      $mask =~ s/l/left /g;
      $mask =~ s/r/right /g;
      $mask =~ s/c/center /g;
      $node->setAttribute("columnalign", $mask);
      $node->setAttribute("displaystyle", "false");

      # stripped isIE handling

      # trying to get a *little* bit of space around the array (IE already includes it)
      my $lspace = $document->createElement("mspace");
      $lspace->setAttribute("width", "0.167em");
      my $rspace = $document->createElement("mspace");
      $rspace->setAttribute("width", "0.167em");
      my $node1 = &AMcreateMmlNode("mrow", $lspace, 1);
      $node1->appendChild($node);
      $node1->appendChild($rspace);

      return ($node1, $result[1], "");

    } else { # eqnarray
      print "passing from AMparseSexpr/Matrix_eqnarray to AMparseExpr, with string: {$str\n" if $debug{trace};
      @result = &AMparseExpr("{".$str, 1, 1);
      print "returning to AMparseSexpr/Matrix_eqnarray to AMparseExpr, with $result[0] / $result[1] / $result[2]\n" if $debug{trace};
      $node = &AMcreateMmlNode("mtable", $result[0], 1);

      # stripped isIE handling
      $node->setAttribute("columnspacing", "0.167em");

      $node->setAttribute("columnalign", "right center left");
      $node->setAttribute("displaystyle", "true");
      $node = &AMcreateMmlNode("mrow", $node, 1);

      return ($node, $result[1], "");
    }


  } elsif ($s_type eq "TEXT") {
    my($i, $st);
    if ($str =~ /^\{/) {
      if ($str =~ /\}/g) { # match up to the first } (doesn't handle nesting)
        $st = substr($str, 1, pos($str)-2);
        $i = length($st) + 2;
      } else { # match everything
        $st = substr($str, 1);
        $i = length($st) + 1;
      }
    } else { # match nothing
      $st = ""; $i = 0;
    }

    if ($st =~ /^\s/) {
      my $node = $document->createElement("mspace");
      $node->setAttribute("width", "0.33em"); # was 1ex
      $newFrag->appendChild($node);
    }

    $newFrag->appendChild(&AMcreateMmlNode($s_tag, $document->createTextNode($st), 1));

    if ($st =~ /\s$/) {
      my $node = $document->createElement("mspace");
      $node->setAttribute("width", "0.33em"); # was 1ex
      $newFrag->appendChild($node);
    }

    $str = &AMremoveCharsAndBlanks($str, $i);
    return (&AMcreateMmlNode("mrow", $newFrag, 1), $str, "");


  } elsif ($s_type eq "UNARY") {
    print "passing from AMparseSexpr/Unary to AMparseSexpr, with string: $str\n" if $debug{trace};
    @result = &AMparseSexpr($str);
    print "returning to AMparseSexpr/Unary from AMparseSexpr, with $result[0] / $result[1] / $result[2]\n" if $debug{trace};

    return (&AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1), $str) if (!defined($result[0]) || $result[0] eq "");

    if ($AMsymbols{$symbol}{func} eq "true") { # functions hack
      my $st = substr($str, 0, 1);

      # handling if it's followed by one of these
      if ($st eq "^" || $st eq "_" || $st eq ",") {
        return (&AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1), $str, $s_tag);

      # default handling
      } else {
        $node = &AMcreateMmlNode("mrow", &AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1), 1);
        # stripped isIE handling
        $node->appendChild($result[0]) if ($result[0]);
        return ($node, $result[1], $s_tag);
      }
    }

    if ($symbol eq "\\\\sqrt") {
      # stripped isIE handling
      return (&AMcreateMmlNode($s_tag, $result[0], 1), $result[1], $s_tag);


    } elsif ($AMsymbols{$symbol}{acc} eq "true") { # accents
      $node = &AMcreateMmlNode($s_tag, $result[0], 1);
      my $output = $s_output;
      # stripped isIE handling
      my $node1 = &AMcreateMmlNode("mo", $document->createTextNode($output), 1);

      if ($symbol eq "\\\\vec" || $symbol eq "\\\\check") { # don't allow to stretch
        $node1->setAttribute("maxsize","1.2");
        # why doesn't "1" work?  \vec nearly disappears in firefox
      }

      # stripped isIE handling

      if ($symbol eq "\\\\underbrace" || $symbol eq "\\\\underline") {
        $node1->setAttribute("accentunder","true");
      } else {
        $node1->setAttribute("accent","true");
      }

      $node->appendChild($node1);

      my($n_underover);
      if ($symbol eq "\\\\overbrace" || $symbol eq "\\\\underbrace" || 
	$symbol eq "\\\\overbracket" || $symbol eq "\\\\underbracket") {
        $n_underover = 1;
      }

      return ($node, $result[1], $s_tag, $n_underover);

    } else {  # font change or displaystyle command
      my ($child, $st, $j);

      # process special character codes (AMcal, AMfrk, AMbbb)
      if ($AMsymbols{$symbol}{codes}) {

        my @childnodes = $result[0]->childNodes;
        foreach $child (@childnodes) {

          if ($child->nodeName eq "mi" || $result[0]->nodeName eq "mi") {

            if ($result[0]->nodeName eq "mi") { $st = $result[0]->firstChild->nodeValue; }
            if ($result[0]->nodeName ne "mi") { $st = $child->firstChild->nodeValue; }

            # note: if you are going to pass the output of this script through FOP/Jeuclid, 
            # comment out the following section and simply set $newst = $st;
            # the special alphabet characters won't display in the converted xhtml file
            # but will appear correctly in the PDF at the end of the process.
            my $newst = "";
            foreach $j (split(//, $st)) {
              # replace capital letters with characters found in code arrays
              if ($j =~ /^[A-Z]$/) {
                $newst .= $AMcal{$j} if ($AMsymbols{$symbol}{codes} eq "AMcal");
                $newst .= $AMfrk{$j} if ($AMsymbols{$symbol}{codes} eq "AMfrk");
                $newst .= $AMbbb{$j} if ($AMsymbols{$symbol}{codes} eq "AMbbb");
              # append all other characters
              } else {
                $newst .= $j;
              }
            }

            if ($result[0]->nodeName eq "mi") {
              print "work: check the other end of unary!!\n";
              $result[0] = $document->createElement("mo")->appendChild($document->createTextNode($newst));
            } else {
              $result[0]->replaceChild(&AMcreateMmlNode("mo", $document->createTextNode($newst), 0), $child); # fixed by PGW
            }

          }
        }
      }

      $node = &AMcreateMmlNode($s_tag, $result[0], 1);
      $node->setAttribute($AMsymbols{$symbol}{atname}, $AMsymbols{$symbol}{atval});
      if ($symbol eq "\\\\scriptstyle" || $symbol eq "\\\\scriptscriptstyle") {
        $node->setAttribute("displaystyle", "false");
      }
      return ($node, $result[1], $s_tag);
    }


  } elsif ($s_type eq "BINARY") {
    print "passing from AMparseSexpr/Binary to AMparseSexpr, with string: $str\n" if $debug{trace};
    @result = &AMparseSexpr($str);
    print "returning to AMparseSexpr/Binary from AMparseSexpr, with $result[0] / $result[1] / $result[2]\n" if $debug{trace};

    if (!defined($result[0]) || $result[0] eq "") {
      return (&AMcreateMmlNode("mo", $document->createTextNode($symbol), 1), $str, "");
    }

    print "passing from AMparseSexpr/Binary2 to AMparseSexpr, with string: $result[1]\n" if $debug{trace};
    @result2 = &AMparseSexpr($result[1]);
    print "returning to AMparseSexpr/Binary2 from AMparseSexpr, with .$result2[0]. / $result2[1] / $result2[2]\n" if $debug{trace};

    if (!defined($result2[0]) || $result2[0] eq "") {
      return (&AMcreateMmlNode("mo", $document->createTextNode($symbol), 1), $str, "");
    }

    if ($symbol eq "\\\\root" || $symbol eq "\\\\stackrel") {
      $newFrag->appendChild($result2[0]);
    }

    $newFrag->appendChild($result[0]);

    if ($symbol eq "\\\\frac") {
      $newFrag->appendChild($result2[0]);
    }

    return(&AMcreateMmlNode($s_tag, $newFrag, 1), $result2[1], $s_tag);


  } elsif ($s_type eq "INFIX") {
    # this only seems to be used to handle /'s, which have been commented out by DRW
    $snip = length($symbol); $snip-- if ($symbol =~ /^\\\\/);
    $str = &AMremoveCharsAndBlanks($str, $snip);
    return (&AMcreateMmlNode("mo", $document->createTextNode($s_output), 1), $str, $s_tag);


  } else { # default
    return (&AMcreateMmlNode($s_tag, $document->createTextNode($s_output), 1), $str, $s_tag);

  }
}

#################################################################

# create a new MathML node for the XML document
sub AMcreateMmlNode {
  my ($t, $frag, $useNS) = @_;
  my ($node);
  $node = $document->createElement($t) unless $useNS;
  $node = $document->createElementNS($config{AMmathml}, $t) if $useNS;
  $node->appendChild($frag);
  return $node;
}

#################################################################

# return the longest initial substring of $str that appears in @AMnames
sub AMgetSymbol {
  my ($str) = @_;
  my ($st, $i);
  my $match = "";

  print "running AMgetSymbol with $str\n" if ($debug{getsymbol});

  # check the string in sequential chunks of increasing size
  $str =~ s/\\/\\\\/g; # double escape characters to match contents of @AMnames
  foreach $i (1 .. length($str)) {
    $st = substr($str, 0, $i);
    #print "test $i: $st\n" if ($debug{getsymbol});

    # AMposition: try to match the substring to AMnames

    # double escape characters for grep
    $st =~ s/\\/\\\\/g;  $st =~ s/\|/\\|/g; 
    $st =~ s/\(/\\\(/g;  $st =~ s/\)/\\\)/g;
    $st =~ s/\[/\\\[/g;  $st =~ s/\]/\\\]/g;
    $st =~ s/\{/\\\{/g;  $st =~ s/\}/\\\}/g;
    $st =~ s/\^/\\\^/g;  $st =~ s/\./\\\./g;
    $st =~ s/\+/\\\+/g;  $st =~ s/\*/\\\*/g;

    if (grep(/^$st$/, @AMnames)) {
      $match = $st;

      # undo double escaping for grep
      $match =~ s/\\\*/\*/g;  $match =~ s/\\\+/\+/g;
      $match =~ s/\\\./\./g;  $match =~ s/\\\^/\^/g;  
      $match =~ s/\\\{/\{/g;  $match =~ s/\\\}/\}/g;
      $match =~ s/\\\[/\[/g;  $match =~ s/\\\]/\]/g;
      $match =~ s/\\\(/\(/g;  $match =~ s/\\\)/\)/g;
      $match =~ s/\\\|/\|/g;  $match =~ s/\\\\/\\/g;  

      print "found exact match for $st = $match\n" if ($debug{getsymbol});
    }

  }

  print "matched $match for $st ($match, $AMsymbols{$match}{output}, $AMsymbols{$match}{ttype}, $AMsymbols{$match}{tag})\n" if ($debug{getsymbol});

  # return longest matching substring and its main parameters
  return ($match, $AMsymbols{$match}{output}, $AMsymbols{$match}{ttype}, $AMsymbols{$match}{tag}) if $match;

  # return null if there is nothing further to process
  return() if (!defined($str) || $str eq "");

  # if $str doesn't match anything in @AMnames, return the first character
  $st = substr($str, 0, 1);
  my $tagst;
  if ($st =~ /^[0-9]$/) {
    $tagst = "mn";
  } elsif ($st =~ /^[A-Za-z]$/) {
    $tagst = "mi";
  } else {
    $tagst = "mo";
  }
  print "return something else - input: $st tag: $tagst output: $st ttype: CONST\n" if ($debug{getsymbol});
  return ($st, $st, "CONST", $tagst);
}

#################################################################

# not using AMcreateElementXHTML.  instead, use:
# my $x = $document->createElementNS("http://www.w3.org/1999/xhtml", $t);

# not using AMcreateElementMathML.  instead, use:
# my $n = $document->createElement($t);

# remove $n characters and any following blanks at start of string
sub AMremoveCharsAndBlanks {
  my ($str, $n) = @_;
  $str = substr($str, $n);
  $str =~ s/^[\s\n]+//g;
  return $str;
}
