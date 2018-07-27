//  LatexPalettesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LatexPalettesController controller is responsible for loading and initializing the palette

#import "LatexPalettesController.h"

#import "AppController.h"
#import "NSPopUpButtonExtended.h"
#import "PaletteCell.h"
#import "PaletteItem.h"
#import "PreferencesController.h"

@interface LatexPalettesController (PrivateAPI)
-(void) _initMatrices;
@end

@implementation LatexPalettesController

-(id) init
{
  if (![super initWithWindowNibName:@"LatexPalettes"])
    return nil;
    
  numberOfItemsPerRow = 4;

  PaletteItem* alpha   = [PaletteItem paletteItemWithName:@"alpha" requires:@""];
  PaletteItem* beta    = [PaletteItem paletteItemWithName:@"beta"  requires:@""];
  PaletteItem* chi     = [PaletteItem paletteItemWithName:@"chi"   requires:@""];
  PaletteItem* delta   = [PaletteItem paletteItemWithName:@"delta" requires:@""];
  PaletteItem* Delta   = [PaletteItem paletteItemWithName:@"Delta"   resourceName:@"delta-big" requires:@""];
  PaletteItem* epsilon = [PaletteItem paletteItemWithName:@"epsilon" requires:@""];
  PaletteItem* eta     = [PaletteItem paletteItemWithName:@"eta"     requires:@""];
  PaletteItem* gamma   = [PaletteItem paletteItemWithName:@"gamma"   requires:@""];
  PaletteItem* Gamma   = [PaletteItem paletteItemWithName:@"Gamma"   resourceName:@"gamma-big" requires:@""];
  PaletteItem* iota    = [PaletteItem paletteItemWithName:@"iota"    requires:@""];
  PaletteItem* kappa   = [PaletteItem paletteItemWithName:@"kappa"   requires:@""];
  PaletteItem* lambda  = [PaletteItem paletteItemWithName:@"lambda"  requires:@""];
  PaletteItem* Lambda  = [PaletteItem paletteItemWithName:@"Lambda"  resourceName:@"lambda-big" requires:@""];
  PaletteItem* mu      = [PaletteItem paletteItemWithName:@"mu"      requires:@""];
  PaletteItem* nu      = [PaletteItem paletteItemWithName:@"nu"      requires:@""];
  PaletteItem* o       = [PaletteItem paletteItemWithName:@"o"       latexCode:@" o" type:LATEX_ITEM_TYPE_KEYWORD requires:@""];
  PaletteItem* omega   = [PaletteItem paletteItemWithName:@"omega"   requires:@""];
  PaletteItem* Omega   = [PaletteItem paletteItemWithName:@"Omega"   resourceName:@"omega-big" requires:@""];
  PaletteItem* phi     = [PaletteItem paletteItemWithName:@"phi"     requires:@""];
  PaletteItem* Phi     = [PaletteItem paletteItemWithName:@"Phi"     resourceName:@"phi-big" requires:@""];
  PaletteItem* pi      = [PaletteItem paletteItemWithName:@"pi"      requires:@""];
  PaletteItem* Pi      = [PaletteItem paletteItemWithName:@"Pi"      resourceName:@"pi-big" requires:@""];
  PaletteItem* psi     = [PaletteItem paletteItemWithName:@"psi"     requires:@""];
  PaletteItem* Psi     = [PaletteItem paletteItemWithName:@"Psi"     resourceName:@"psi-big" requires:@""];
  PaletteItem* rho     = [PaletteItem paletteItemWithName:@"rho"     requires:@""];
  PaletteItem* sigma   = [PaletteItem paletteItemWithName:@"sigma"   requires:@""];
  PaletteItem* Sigma   = [PaletteItem paletteItemWithName:@"Sigma"   resourceName:@"sigma-big" requires:@""];
  PaletteItem* tau     = [PaletteItem paletteItemWithName:@"tau"     requires:@""];
  PaletteItem* theta   = [PaletteItem paletteItemWithName:@"theta"   requires:@""];
  PaletteItem* Theta   = [PaletteItem paletteItemWithName:@"Theta"   resourceName:@"theta-big" requires:@""];
  PaletteItem* upsilon = [PaletteItem paletteItemWithName:@"upsilon" requires:@""];
  PaletteItem* Upsilon = [PaletteItem paletteItemWithName:@"Upsilon" resourceName:@"upsilon-big" requires:@""];
  PaletteItem* varphi  = [PaletteItem paletteItemWithName:@"varphi"  requires:@""];
  PaletteItem* xi      = [PaletteItem paletteItemWithName:@"xi"      requires:@""];
  PaletteItem* Xi      = [PaletteItem paletteItemWithName:@"Xi"      resourceName:@"xi-big" requires:@""];
  PaletteItem* zeta    = [PaletteItem paletteItemWithName:@"zeta"    requires:@""];
  greekItems = [[NSArray alloc] initWithObjects:alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, mu,
                                                nu, xi, o, pi, rho, sigma, tau, upsilon, varphi, chi, psi, omega,
                                                Gamma, Delta, Theta, Lambda, Pi, Sigma, Xi, Upsilon, phi, Phi, Psi, Omega, nil];

  PaletteItem* aleph     = [PaletteItem paletteItemWithName:@"aleph"     requires:@""];
  PaletteItem* ell       = [PaletteItem paletteItemWithName:@"ell"       requires:@""];
  PaletteItem* emptyset  = [PaletteItem paletteItemWithName:@"emptyset"  requires:@""];
  PaletteItem* hbar      = [PaletteItem paletteItemWithName:@"hbar"      requires:@""];
  PaletteItem* hmathbb   = [PaletteItem paletteItemWithName:@"mathbb{H}" resourceName:@"h-mathbb" requires:@"amssymb"];
  PaletteItem* im        = [PaletteItem paletteItemWithName:@"Im"        resourceName:@"im" requires:@""];
  PaletteItem* imath     = [PaletteItem paletteItemWithName:@"imath"     requires:@""];
  PaletteItem* infty     = [PaletteItem paletteItemWithName:@"infty"     requires:@""];
  PaletteItem* jmath     = [PaletteItem paletteItemWithName:@"jmath"     requires:@""];
  PaletteItem* nabla     = [PaletteItem paletteItemWithName:@"nabla"     requires:@""];
  PaletteItem* nmathbb   = [PaletteItem paletteItemWithName:@"mathbb{N}" resourceName:@"n-mathbb" requires:@"amssymb"];
  PaletteItem* pmathbb   = [PaletteItem paletteItemWithName:@"mathbb{P}" resourceName:@"p-mathbb" requires:@"amssymb"];
  PaletteItem* qmathbb   = [PaletteItem paletteItemWithName:@"mathbb{Q}" resourceName:@"q-mathbb" requires:@"amssymb"];
  PaletteItem* re        = [PaletteItem paletteItemWithName:@"Re"        resourceName:@"re" requires:@""];
  PaletteItem* rmathbb   = [PaletteItem paletteItemWithName:@"mathbb{R}" resourceName:@"r-mathbb" requires:@"amssymb"];
  PaletteItem* zmathbb   = [PaletteItem paletteItemWithName:@"mathbb{Z}" resourceName:@"z-mathbb" requires:@"amssymb"];
  lettersItems = [[NSArray alloc] initWithObjects:nmathbb, zmathbb, qmathbb, pmathbb,
                                                  rmathbb, hmathbb, re, im,
                                                  hbar, imath, jmath, ell,
                                                  aleph, infty, Delta, nabla,
                                                  emptyset, nil];

  PaletteItem* approx     = [PaletteItem paletteItemWithName:@"approx"     requires:@""];
  PaletteItem* asymp      = [PaletteItem paletteItemWithName:@"asymp"      requires:@""];
  PaletteItem* bot        = [PaletteItem paletteItemWithName:@"bot"        requires:@""];
  PaletteItem* bowtie     = [PaletteItem paletteItemWithName:@"bowtie"     requires:@""];
  PaletteItem* cong       = [PaletteItem paletteItemWithName:@"cong"       requires:@""];
  PaletteItem* dashv      = [PaletteItem paletteItemWithName:@"dashv"      requires:@""];
  PaletteItem* doteq      = [PaletteItem paletteItemWithName:@"doteq"      requires:@""];
  PaletteItem* equiv      = [PaletteItem paletteItemWithName:@"equiv"      requires:@""];
  PaletteItem* geq        = [PaletteItem paletteItemWithName:@"geq"        requires:@""];
  PaletteItem* geqslant   = [PaletteItem paletteItemWithName:@"geqslant"   requires:@"amssymb"];
  PaletteItem* gg         = [PaletteItem paletteItemWithName:@"gg"         requires:@""];
  PaletteItem* ggg        = [PaletteItem paletteItemWithName:@"ggg"        requires:@"amssymb"];
  PaletteItem* gtrsim     = [PaletteItem paletteItemWithName:@"gtrsim"     requires:@"amssymb"];
  PaletteItem* in_        = [PaletteItem paletteItemWithName:@"in"         requires:@""];
  PaletteItem* leq        = [PaletteItem paletteItemWithName:@"leq"        requires:@""];
  PaletteItem* leqslant   = [PaletteItem paletteItemWithName:@"leqslant"   requires:@"amssymb"];
  PaletteItem* lesssim    = [PaletteItem paletteItemWithName:@"lesssim"    requires:@"amssymb"];
  PaletteItem* ll         = [PaletteItem paletteItemWithName:@"ll"         requires:@""];
  PaletteItem* lll        = [PaletteItem paletteItemWithName:@"lll"        requires:@"amssymb"];
  PaletteItem* ltimes     = [PaletteItem paletteItemWithName:@"ltimes"     requires:@"amssymb"];
  PaletteItem* mid        = [PaletteItem paletteItemWithName:@"mid"        requires:@""];
  PaletteItem* models     = [PaletteItem paletteItemWithName:@"models"     requires:@""];
  PaletteItem* neq        = [PaletteItem paletteItemWithName:@"neq"        requires:@""];
  PaletteItem* ngeq       = [PaletteItem paletteItemWithName:@"ngeq"       requires:@"amssymb"];
  PaletteItem* ngeqslant  = [PaletteItem paletteItemWithName:@"ngeqslant"  requires:@"amssymb"];
  PaletteItem* ni         = [PaletteItem paletteItemWithName:@"ni"         requires:@""];
  PaletteItem* nleq       = [PaletteItem paletteItemWithName:@"nleq"       requires:@"amssymb"];
  PaletteItem* nleqslant  = [PaletteItem paletteItemWithName:@"nleqslant"  requires:@"amssymb"];
  PaletteItem* nmid       = [PaletteItem paletteItemWithName:@"nmid"       requires:@"amssymb"];
  PaletteItem* notin      = [PaletteItem paletteItemWithName:@"notin"      requires:@""];
  PaletteItem* nparallel  = [PaletteItem paletteItemWithName:@"nparallel"  requires:@"amssymb"];
  PaletteItem* nprec      = [PaletteItem paletteItemWithName:@"nprec"      requires:@"amssymb"];
  PaletteItem* npreceq    = [PaletteItem paletteItemWithName:@"npreceq"    requires:@"amssymb"];
  PaletteItem* nsubseteq  = [PaletteItem paletteItemWithName:@"nsubseteq"  requires:@"amssymb"];
  PaletteItem* nsucc      = [PaletteItem paletteItemWithName:@"nsucc"      requires:@"amssymb"];
  PaletteItem* nsucceq    = [PaletteItem paletteItemWithName:@"nsucceq"    requires:@"amssymb"];
  PaletteItem* nsupseteq  = [PaletteItem paletteItemWithName:@"nsupseteq"  requires:@"amssymb"];
  PaletteItem* parallel   = [PaletteItem paletteItemWithName:@"parallel"   requires:@""];
  PaletteItem* prec       = [PaletteItem paletteItemWithName:@"prec"       requires:@""];
  PaletteItem* preceq     = [PaletteItem paletteItemWithName:@"preceq"     requires:@""];
  PaletteItem* propto     = [PaletteItem paletteItemWithName:@"propto"     requires:@""];  
  PaletteItem* rtimes     = [PaletteItem paletteItemWithName:@"rtimes"     requires:@"amssymb"];
  PaletteItem* sim        = [PaletteItem paletteItemWithName:@"sim"        requires:@""];
  PaletteItem* simeq      = [PaletteItem paletteItemWithName:@"simeq"      requires:@""];
  PaletteItem* sqsubset   = [PaletteItem paletteItemWithName:@"sqsubset"   requires:@"amssymb"];
  PaletteItem* sqsubseteq = [PaletteItem paletteItemWithName:@"sqsubseteq" requires:@""];
  PaletteItem* sqsupset   = [PaletteItem paletteItemWithName:@"sqsupset"   requires:@"amssymb"];
  PaletteItem* sqsupseteq = [PaletteItem paletteItemWithName:@"sqsupseteq" requires:@""];
  PaletteItem* subset     = [PaletteItem paletteItemWithName:@"subset"     requires:@""];
  PaletteItem* subseteq   = [PaletteItem paletteItemWithName:@"subseteq"   requires:@""];
  PaletteItem* succ       = [PaletteItem paletteItemWithName:@"succ"       requires:@""];
  PaletteItem* succeq     = [PaletteItem paletteItemWithName:@"succeq"     requires:@""];
  PaletteItem* supset     = [PaletteItem paletteItemWithName:@"supset"     requires:@""];
  PaletteItem* supseteq   = [PaletteItem paletteItemWithName:@"supseteq"   requires:@""];
  PaletteItem* top        = [PaletteItem paletteItemWithName:@"top"        requires:@""];
  PaletteItem* vdash      = [PaletteItem paletteItemWithName:@"vdash"      requires:@""];
  relationsItems = [[NSArray alloc] initWithObjects:leq, geq, nleq, ngeq,
                                                    leqslant, geqslant, nleqslant, ngeqslant,
                                                    prec, succ, nprec, nsucc,
                                                    preceq, succeq, npreceq, nsucceq,
                                                    subset, supset, subseteq, supseteq,
                                                    sqsubset, sqsupset, sqsubseteq, sqsupseteq,
                                                    nsubseteq, nsupseteq, lesssim, gtrsim,
                                                    ll, gg, lll, ggg,
                                                    sim, approx, simeq, neq,
                                                    asymp, doteq, cong, equiv,
                                                    in_, ni, notin, models,
                                                    vdash, dashv, bot, top,
                                                    propto, ltimes, rtimes, bowtie,
                                                    mid, nmid, parallel, nparallel, nil];

  PaletteItem* amalg           = [PaletteItem paletteItemWithName:@"amalg"           requires:@""];
  PaletteItem* ast             = [PaletteItem paletteItemWithName:@"ast"             requires:@""];
  PaletteItem* bigcirc         = [PaletteItem paletteItemWithName:@"bigcirc"         requires:@""];
  PaletteItem* bigtriangledown = [PaletteItem paletteItemWithName:@"bigtriangledown" requires:@"amssymb"];
  PaletteItem* bigtriangleup   = [PaletteItem paletteItemWithName:@"bigtriangleup"   requires:@"amssymb"];
  PaletteItem* bullet          = [PaletteItem paletteItemWithName:@"bullet"          requires:@""];
  PaletteItem* cap             = [PaletteItem paletteItemWithName:@"cap"             requires:@""];
  PaletteItem* cdot            = [PaletteItem paletteItemWithName:@"cdot"            requires:@""];
  PaletteItem* circ            = [PaletteItem paletteItemWithName:@"circ"            requires:@""];
  PaletteItem* cup             = [PaletteItem paletteItemWithName:@"cup"             requires:@""];
  PaletteItem* dagger          = [PaletteItem paletteItemWithName:@"dagger"          requires:@""];
  PaletteItem* ddagger         = [PaletteItem paletteItemWithName:@"ddagger"         requires:@""];
  PaletteItem* diamond         = [PaletteItem paletteItemWithName:@"diamond"         requires:@""];
  PaletteItem* div             = [PaletteItem paletteItemWithName:@"div"             requires:@""];
  PaletteItem* mp              = [PaletteItem paletteItemWithName:@"mp"              requires:@""];
  PaletteItem* odot            = [PaletteItem paletteItemWithName:@"odot"            requires:@""];
  PaletteItem* ominus          = [PaletteItem paletteItemWithName:@"ominus"          requires:@""];
  PaletteItem* oplus           = [PaletteItem paletteItemWithName:@"oplus"           requires:@""];  
  PaletteItem* oslash          = [PaletteItem paletteItemWithName:@"oslash"          requires:@""];
  PaletteItem* otimes          = [PaletteItem paletteItemWithName:@"otimes"          requires:@""];
  PaletteItem* pm              = [PaletteItem paletteItemWithName:@"pm"              requires:@""];
  //PaletteItem* propto          = [PaletteItem paletteItemWithName:@"propto" requires:@""];  
  PaletteItem* setminus        = [PaletteItem paletteItemWithName:@"setminus"        requires:@""];
  PaletteItem* sqcap           = [PaletteItem paletteItemWithName:@"sqcap"           requires:@""];
  PaletteItem* sqcup           = [PaletteItem paletteItemWithName:@"sqcup"           requires:@""];
  PaletteItem* star            = [PaletteItem paletteItemWithName:@"star"            requires:@""];  
  PaletteItem* times           = [PaletteItem paletteItemWithName:@"times"           requires:@""];
  PaletteItem* triangleleft    = [PaletteItem paletteItemWithName:@"triangleleft"    requires:@""];
  PaletteItem* triangleright   = [PaletteItem paletteItemWithName:@"triangleright"   requires:@""];
  PaletteItem* unlhd           = [PaletteItem paletteItemWithName:@"unlhd"           requires:@"amssymb"];  
  PaletteItem* unrhd           = [PaletteItem paletteItemWithName:@"unrhd"           requires:@"amssymb"];
  PaletteItem* uplus           = [PaletteItem paletteItemWithName:@"uplus"           requires:@""];
  PaletteItem* vee             = [PaletteItem paletteItemWithName:@"vee"             requires:@""];
  PaletteItem* wedge           = [PaletteItem paletteItemWithName:@"wedge"           requires:@""];  
  PaletteItem* wr              = [PaletteItem paletteItemWithName:@"wr"              requires:@""];
  binaryOperatorsItems = [[NSArray alloc] initWithObjects:pm, mp, times, div,
                                                          ast, star, setminus, wr,
                                                          circ, bullet, cdot, diamond,
                                                          triangleleft, triangleright, unlhd, unrhd,
                                                          bigtriangleup, bigtriangledown, vee, wedge,
                                                          cup, cap, sqcup, sqcap,
                                                          oplus, ominus, otimes, oslash,
                                                          odot, bigcirc, uplus, amalg,
                                                          dagger, ddagger, propto, nil];

  PaletteItem* bigcap   = [PaletteItem paletteItemWithName:@"bigcap"   requires:@""];
  PaletteItem* bigcup   = [PaletteItem paletteItemWithName:@"bigcup"   requires:@""];
  PaletteItem* bigvee   = [PaletteItem paletteItemWithName:@"bigvee"   requires:@""];
  PaletteItem* bigwedge = [PaletteItem paletteItemWithName:@"bigwedge" requires:@""];
  PaletteItem* coprod   = [PaletteItem paletteItemWithName:@"coprod"   requires:@""];
  PaletteItem* exists   = [PaletteItem paletteItemWithName:@"exists"   requires:@""];
  PaletteItem* forall   = [PaletteItem paletteItemWithName:@"forall"   requires:@""];
  PaletteItem* int_     = [PaletteItem paletteItemWithName:@"int"      requires:@""];
  PaletteItem* iint     = [PaletteItem paletteItemWithName:@"iint"     requires:@"amsmath"];
  PaletteItem* iiint    = [PaletteItem paletteItemWithName:@"iiint"    requires:@"amsmath"];
  PaletteItem* neg      = [PaletteItem paletteItemWithName:@"neg"      requires:@""];
  PaletteItem* nexists  = [PaletteItem paletteItemWithName:@"nexists"  requires:@"amssymb"];
  PaletteItem* oint     = [PaletteItem paletteItemWithName:@"oint"     requires:@""];
  PaletteItem* partial  = [PaletteItem paletteItemWithName:@"partial"  requires:@""];
  PaletteItem* prod     = [PaletteItem paletteItemWithName:@"prod"     requires:@""];
  PaletteItem* sqrt_    = [PaletteItem paletteItemWithName:@"sqrt"  type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* sqrt3_   = [PaletteItem paletteItemWithName:@"sqrt3" latexCode:@"\\sqrt[3]" type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* sum      = [PaletteItem paletteItemWithName:@"sum"    requires:@""];
  otherOperatorsItems = [[NSArray alloc] initWithObjects:sum, prod, coprod, partial,
                                                         Delta, nabla, sqrt_, sqrt3_,
                                                         int_, oint, iint, iiint,
                                                         bigcup, bigcap, bigvee, bigwedge,
                                                         neg, forall, exists, nexists, nil];

  PaletteItem* downarrow         = [PaletteItem paletteItemWithName:@"downarrow"        requires:@""];
  PaletteItem* hookleftarrow     = [PaletteItem paletteItemWithName:@"hookleftarrow"    requires:@""];
  PaletteItem* hookrightarrow    = [PaletteItem paletteItemWithName:@"hookrightarrow"   requires:@""];
  PaletteItem* leftarrow         = [PaletteItem paletteItemWithName:@"leftarrow"        requires:@""];
  PaletteItem* Leftarrow         = [PaletteItem paletteItemWithName:@"Leftarrow"        resourceName:@"leftarrow-big" requires:@""];
  PaletteItem* leftharpoondown   = [PaletteItem paletteItemWithName:@"leftharpoondown"  requires:@""];
  PaletteItem* leftharpoonup     = [PaletteItem paletteItemWithName:@"leftharpoonup"    requires:@""];
  PaletteItem* leftrightarrow    = [PaletteItem paletteItemWithName:@"leftrightarrow"   requires:@""];
  PaletteItem* Leftrightarrow    = [PaletteItem paletteItemWithName:@"Leftrightarrow"   resourceName:@"leftrightarrow-big" requires:@""];
  PaletteItem* longmapsto        = [PaletteItem paletteItemWithName:@"longmapsto"       requires:@""];
  PaletteItem* looparrowleft     = [PaletteItem paletteItemWithName:@"looparrowleft"    requires:@"amssymb"];
  PaletteItem* looparrowright    = [PaletteItem paletteItemWithName:@"looparrowright"   requires:@"amssymb"];
  PaletteItem* mapsto            = [PaletteItem paletteItemWithName:@"mapsto"           requires:@""];
  PaletteItem* nearrow           = [PaletteItem paletteItemWithName:@"nearrow"          requires:@""];
  PaletteItem* nwarrow           = [PaletteItem paletteItemWithName:@"nwarrow"          requires:@""];
  PaletteItem* rightarrow        = [PaletteItem paletteItemWithName:@"rightarrow"       requires:@""];
  PaletteItem* Rightarrow        = [PaletteItem paletteItemWithName:@"Rightarrow"       resourceName:@"rightarrow-big" requires:@""];
  PaletteItem* rightharpoondown  = [PaletteItem paletteItemWithName:@"rightharpoondown" requires:@""];
  PaletteItem* rightharpoonup    = [PaletteItem paletteItemWithName:@"rightharpoonup"   requires:@""];
  PaletteItem* searrow           = [PaletteItem paletteItemWithName:@"searrow"          requires:@""];
  PaletteItem* swarrow           = [PaletteItem paletteItemWithName:@"swarrow"          requires:@""];
  PaletteItem* uparrow           = [PaletteItem paletteItemWithName:@"uparrow"          requires:@""];
  arrowsItems = [[NSArray alloc] initWithObjects:leftarrow, uparrow, rightarrow, downarrow, nwarrow, nearrow, searrow, swarrow,
                                                 leftharpoonup, leftharpoondown, rightharpoonup, rightharpoondown,
                                                 hookleftarrow, hookrightarrow, looparrowleft, looparrowright, Leftarrow, Rightarrow,
                                                 Leftrightarrow, leftrightarrow, mapsto, longmapsto, nil];

  PaletteItem* bar             = [PaletteItem paletteItemWithName:@"bar"             type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* dot             = [PaletteItem paletteItemWithName:@"dot"             type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* ddot            = [PaletteItem paletteItemWithName:@"ddot"            type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* hat             = [PaletteItem paletteItemWithName:@"hat"             type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* overbrace       = [PaletteItem paletteItemWithName:@"overbrace"       type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* overleftarrow   = [PaletteItem paletteItemWithName:@"overleftarrow"   type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* overrightarrow  = [PaletteItem paletteItemWithName:@"overrightarrow"  type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* tilde           = [PaletteItem paletteItemWithName:@"tilde"           type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* underbrace      = [PaletteItem paletteItemWithName:@"underbrace"      type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* underleftarrow  = [PaletteItem paletteItemWithName:@"underleftarrow"  type:LATEX_ITEM_TYPE_FUNCTION requires:@"amsmath"];
  PaletteItem* underrightarrow = [PaletteItem paletteItemWithName:@"underrightarrow" type:LATEX_ITEM_TYPE_FUNCTION requires:@"amsmath"];
  PaletteItem* vec             = [PaletteItem paletteItemWithName:@"vec"             type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* widehat         = [PaletteItem paletteItemWithName:@"widehat"         type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  PaletteItem* widetilde       = [PaletteItem paletteItemWithName:@"widetilde"       type:LATEX_ITEM_TYPE_FUNCTION requires:@""];
  decorationsItems = [[NSArray alloc] initWithObjects:overleftarrow, overrightarrow, underleftarrow, underrightarrow, vec,
                                                      hat, widehat, tilde, widetilde, bar, dot, ddot, overbrace, underbrace, nil];

  groups = [[NSArray alloc] initWithObjects:greekItems, lettersItems, relationsItems, binaryOperatorsItems,
                                            otherOperatorsItems, arrowsItems, decorationsItems, nil];
                                            
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification object:nil];
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [groups release];
  [greekItems release];
  [lettersItems release];
  [binaryOperatorsItems release];
  [otherOperatorsItems release];
  [arrowsItems release];
  [decorationsItems release];
  [super dealloc];
}

-(void) windowDidResize:(NSNotification*)notification
{
  float clipViewWidth = [[[matrix superview] superview] frame].size.width-[NSScroller scrollerWidth]+1;
  float cellWidth = floor(clipViewWidth/numberOfItemsPerRow);
  [matrix setCellSize:NSMakeSize(cellWidth, cellWidth)];
  [matrix setFrame:NSMakeRect(0, 0,  floor(cellWidth*[matrix numberOfColumns]), cellWidth*[matrix numberOfRows])];
  [matrix setNeedsDisplay:YES];
}

-(void) awakeFromNib
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:)
                                               name:NSWindowDidResizeNotification object:[self window]];
  [matrix setDelegate:self];
  [matrixChoicePopUpButton selectItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:LatexPaletteGroupKey]];
  [matrix setNextKeyView:matrixChoicePopUpButton];
  [self changeGroup:matrixChoicePopUpButton];
  [self latexPalettesSelect:nil];
}

-(void) windowDidLoad
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSWindow* window = [self window];
  [window setAcceptsMouseMovedEvents:YES];
  NSRect defaultFrame = NSRectFromString([userDefaults stringForKey:LatexPaletteFrameKey]);
  BOOL   defaultDetails = [userDefaults boolForKey:LatexPaletteDetailsStateKey];
  if (defaultDetails)
  {
    defaultFrame.size.height -= [detailsBox frame].size.height;
    defaultFrame.origin.y    += [detailsBox frame].size.height;
  }
  [window setFrame:defaultFrame display:YES];
  [window setMinSize:NSMakeSize(200, 170)];
  [detailsButton setState:defaultDetails ? NSOnState : NSOffState];
  if (defaultDetails)
    [self openOrHideDetails:detailsButton];
}

-(void) mouseMoved:(NSEvent*)event
{
  NSClipView* clipView = (NSClipView*) [matrix superview];
  NSPoint locationInWindow = [event locationInWindow];
  NSPoint location = [clipView convertPoint:locationInWindow fromView:nil];
  NSRect clipBounds = [clipView bounds];
  if (NSPointInRect(location, clipBounds))
  {
    int row = -1;
    int column = 0;
    BOOL ok = [matrix getRow:&row column:&column forPoint:[matrix convertPoint:location fromView:clipView]];
    if (ok)
    {
    
      [matrix selectCellAtRow:row column:column];
      [self latexPalettesSelect:matrix];
      [clipView setBounds:clipBounds];
      [clipView setNeedsDisplay:YES];
    }
  }
}

//triggered when the user selects an element on the palette
-(IBAction) latexPalettesSelect:(id)sender
{
  PaletteItem* selectedItem = [[matrix selectedCell] representedObject];
  if (!selectedItem || ![selectedItem requires] || [[selectedItem requires] isEqualToString:@""] )
    [detailsRequiresTextField setStringValue:@"-"];
  else
    [detailsRequiresTextField setStringValue:[NSString stringWithFormat:@"\\usepackage{%@}", [selectedItem requires]]];
  NSImage* image = [selectedItem image];
  if (image) //expands the image to fill the imageView proportionnaly
  {
    NSSize imageSize = [image size];
    NSSize frameSize = [detailsImageView bounds].size;
    float ratio = imageSize.height ? imageSize.width/imageSize.height : 1.f;
    imageSize = frameSize;
    if (ratio <= 1) //width <= height
      imageSize.width *= ratio;
    else
      imageSize.height /= ratio;
    [image setSize:imageSize];
  }
  [detailsImageView setImage:image];
  [detailsLatexCodeTextField setStringValue:selectedItem ? [selectedItem latexCode] : @"-"];
}

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesClick:(id)sender
{
  [self latexPalettesSelect:sender];
  [[AppController appController] latexPalettesClick:sender];
}

-(IBAction) changeGroup:(id)sender
{
  int group = [sender selectedTag];
  NSArray* items = [groups objectAtIndex:group];
  unsigned int nbItems = [items count];
  int nbColumns = numberOfItemsPerRow;
  int nbRows    = (nbItems/numberOfItemsPerRow+1)+(nbItems%numberOfItemsPerRow ? 0 : -1);
  PaletteCell* prototype = [[[PaletteCell alloc] initImageCell:nil] autorelease];
  [prototype setImageAlignment:NSImageAlignCenter];
  [prototype setImageScaling:NSScaleToFit];
  while([matrix numberOfRows])
    [matrix removeRow:0];
  [matrix setPrototype:prototype];
  [matrix renewRows:nbRows columns:nbColumns];
  unsigned int i = 0;
  for(i = 0 ; i<nbItems ; ++i)
  {
    int row    = i/numberOfItemsPerRow;
    int column = i%numberOfItemsPerRow;
    NSImageCell* cell = (NSImageCell*) [matrix cellAtRow:row column:column];
    PaletteItem* item = [items objectAtIndex:i];
    [cell setRepresentedObject:item];
    [cell setImage:[item image]];
    [matrix setToolTip:[item toolTip] forCell:cell]; 
  }
  [self windowDidResize:nil];
  [[NSUserDefaults standardUserDefaults] setInteger:group forKey:LatexPaletteGroupKey];
  [self latexPalettesSelect:nil];
}

-(IBAction) openOrHideDetails:(id)sender
{
  if (!sender)
    sender = detailsButton;

  if ([sender state] == NSOnState)
  {
    unsigned int oldMatrixAutoresizingMask = [matrixBox autoresizingMask];
    [matrixBox setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin];

    [detailsBox retain];
    [detailsBox removeFromSuperviewWithoutNeedingDisplay];
    
    NSWindow* window = [self window];
    NSRect windowFrame = [window frame];
    NSRect detailsBoxFrame = [detailsBox frame];
    windowFrame.size.height += detailsBoxFrame.size.height;
    windowFrame.origin.y    -= detailsBoxFrame.size.height;
    [window setFrame:windowFrame display:YES animate:YES];
    
    NSView* contentView = [window contentView];
    NSRect contentViewFrame = [contentView frame];
    [contentView addSubview:detailsBox];
    [detailsBox setFrame:NSMakeRect(0, 0, contentViewFrame.size.width, [detailsBox frame].size.height)];
    
    [matrixBox setAutoresizingMask:oldMatrixAutoresizingMask];
    
    NSSize minSize = [window minSize];
    minSize.height += [detailsBox frame].size.height;
    [window setMinSize:minSize];
    
    [window display];
  }
  else
  {
    unsigned int oldMatrixAutoresizingMask = [matrixBox autoresizingMask];
    [matrixBox setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin];

    [detailsBox retain];
    [detailsBox removeFromSuperviewWithoutNeedingDisplay];
    
    NSWindow* window = [self window];
    NSRect windowFrame = [window frame];
    NSRect detailsBoxFrame = [detailsBox frame];
    windowFrame.size.height -= detailsBoxFrame.size.height;
    windowFrame.origin.y    += detailsBoxFrame.size.height;
    [window setFrame:windowFrame display:YES animate:YES];

    [matrixBox setAutoresizingMask:oldMatrixAutoresizingMask];

    NSSize minSize = [window minSize];
    minSize.height -= [detailsBox frame].size.height;
    [window setMinSize:minSize];

    [window display];
  }
}

-(void) applicationWillTerminate:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:NSStringFromRect([[self window] frame]) forKey:LatexPaletteFrameKey];
  [userDefaults setBool:([detailsButton state] == NSOnState) forKey:LatexPaletteDetailsStateKey];
}

@end
