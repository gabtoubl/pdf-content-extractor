%option noinput
%option nounput
%option stack
%option nodefault
 //%option debug
%option noyy_top_state
%{
  #include <iostream>
  #include "parserlexer.hpp"
  #include "bison.hpp"

  using namespace std;

  static void switch_state(int);
  static int prev_yyleng;
%}

%x header
%x body bodyObj bodyObjArr bodyObjDic bodyObjStream bodyObjInd
%x xref xrefSection xrefField
%x trailer eof
%x txtStream

name \/[a-zA-Z0-9#+-._:?]+
nb   [\+-]?[0-9]+
flt  [\+-]?[0-9]*\.[0-9]+
str  \((\\\)|[^)])*\)
%%
.                                {yyless(0); yy_push_state(header);}

<header>%PDF-[0-9]\.[0-9]        {yylval.s = yytext + 5; return VERSION;}
<header>%[^!-~]*
<header>[^\n\r]                  {yyless(0); switch_state(body);}

<body>%.*
<body>[0-9]+                     {yylval.i = atoi(yytext); return NB;}
<body>obj                        {yy_push_state(bodyObj); return OBJ;}
<body>[^t]xref                   {switch_state(xref); return XREF;}

<bodyObj>stream\n                {yy_push_state(bodyObjStream); return STREAM;}
<bodyObj>endobj                  {yy_pop_state(); return ENDOBJ;}

<bodyObj,bodyObjArr,bodyObjDic>{
    true|false                   {yylval.b = yytext[0] == 't' ? true : false; return BOOL;}
    null                         {return NIL;}
    {nb}                         {yylval.i = atoi(yytext); return NB;}
    {flt}                        {yylval.f = atof(yytext); return FLOAT;}
    [0-9]+\ [0-9]+\ R            {yyless(0); yy_push_state(bodyObjInd); return IND;}
    {name}                       {yylval.s = yytext; return NAME;}
    \(.*\)|\<\>|\<[^<>][^>]*\>   {yylval.s = yytext; return STRING;}
    \[                           {yy_push_state(bodyObjArr); return ARR;}
    \]                           {yy_pop_state(); return ENDARR;}
    \<\<                         {yy_push_state(bodyObjDic); return DIC;}
    \>\>                         {yy_pop_state(); return ENDDIC;}
}

<bodyObjStream>endstream\ *\r?\n {yy_pop_state(); yylval.s = yytext; yyleng = prev_yyleng - 1; return ENDSTREAM;}
<bodyObjStream>.*\r?\n           {yymore(); prev_yyleng = yyleng - 1;}

<bodyObjInd>[0-9]+               {yylval.i = atoi(yytext); return NB;}
<bodyObjInd>R                    {yy_pop_state(); return ENDIND;}

<xref>[0-9]+\ +[0-9]+\n          {yyless(0); yy_push_state(xrefSection); return XREFSECTION;}

<xrefSection>[0-9]+              {yylval.i = atoi(yytext); return NB;}
<xrefSection>\n                  {yy_push_state(xrefField);}

<xrefField>[0-9]+\ +[0-9]+\n     {yyless(0); yy_pop_state(); yy_pop_state();}
<xrefField>trailer               {yyless(0); yy_pop_state(); yy_pop_state();}
<xrefField>[0-9]+                {yylval.i = atoi(yytext); return NB;}
<xrefField>f|n                   {yylval.b = yytext[0] == 'f' ? true : false; return BOOL;}

<xref>trailer                    {switch_state(trailer); return TRAILER;}

<trailer><<                      {yy_push_state(bodyObjDic); return DIC;}
<trailer>startxref               {return STARTXREF;}
<trailer>[0-9]+                  {yylval.i = atoi(yytext); return NB;}
<trailer>%%EOF                   {switch_state(eof); return ENDOFFILE;}

<eof>.|\n                        {yy_pop_state(); yyterminate();}

<txtStream>BT                   {return BEGINTXT;}
<txtStream>{nb}|{flt}           {yylval.f = atof(yytext); return FLOAT;}
<txtStream>{name}               {yylval.s = yytext; return NAME;}
<txtStream>{str}                {yylval.s = yytext; return STRING;}
<txtStream>\[                   {return ARR;}
<txtStream>\]                   {return ENDARR;}
<txtStream>Tf                   {return OP_TF;}
<txtStream>Td                   {return OP_TD;}
<txtStream>TJ                   {return OP_TJ;}
<txtStream>ET                   {return ENDTXT;}

<*>.|\n
%%

/*
Règles à ajouter pour voir ce qui ne passes pas dans le lexer, combinable avec l'option debug
Supprimer:
<*>.|\n
Ajouter:
<*>\ |\n
<*>. cerr << "error:'"<<yytext<<"'"<<endl;
*/

static void switch_state(int newState) {
  yy_pop_state();
  yy_push_state(newState);
}

void set_text_stream_state() {
  yyrestart(yyin);
  yy_push_state(txtStream);
}

void reset_initial_state() {
  yyrestart(yyin);
  BEGIN(INITIAL);
}
