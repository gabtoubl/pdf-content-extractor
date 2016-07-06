%option noinput
%option nounput
%option stack
%option nodefault
 //%option debug
%option noyy_top_state
%{
  #include <iostream>
  #include "parserlexer.hpp"
  #include "bison.h"

  using namespace std;

  static void switch_state(int);
%}

%x header
%x body bodyObj bodyObjArr bodyObjDic bodyObjStream bodyObjInd
%x xref xrefSection xrefField
%x trailer eof

%%
.                                {yyless(0); yy_push_state(header);}

<header>%PDF-[0-9]\.[0-9]        {yylval.s = strdup(yytext + 5); return VERSION;}
<header>%[^!-~]*
<header>[^\n\r]                  {yyless(0); switch_state(body);}

<body>%.*
<body>[0-9]+                     {yylval.i = atoi(yytext); return NB;}
<body>obj                        {yy_push_state(bodyObj); return OBJ;}
<body>[^t]xref                   {switch_state(xref); return XREF;}

<bodyObj>stream                  {yy_push_state(bodyObjStream); return STREAM;}
<bodyObj>endobj                  {yy_pop_state(); return ENDOBJ;}

<bodyObj,bodyObjArr,bodyObjDic>{
    true|false                   {yylval.b = yytext[0] == 't' ? true : false; return BOOL;}
    null                         {return NIL;}
    (\+|-)?[0-9]+                {yylval.i = atoi(yytext); return NB;}
    (\+|-)?[0-9]+\.[0-9]+        {yylval.f = atof(yytext); return FLOAT;}
    [0-9]+\ [0-9]+\ R            {yyless(0); yy_push_state(bodyObjInd); return IND;}
    \/[a-zA-Z0-9#+-._:?]+        {yylval.s = strdup(yytext); return NAME;}
    \(.*\)|\<\>|\<[^<>][^>]*\>   {yylval.s = strdup(yytext); return STRING;}
    \[                           {yy_push_state(bodyObjArr); return ARR;}
    \]                           {yy_pop_state(); return ENDARR;}
    \<\<                         {yy_push_state(bodyObjDic); return DIC;}
    \>\>                         {yy_pop_state(); return ENDDIC;}
}

<bodyObjStream>endstream\ *\r?\n {yy_pop_state(); yylval.s = yytext; return ENDSTREAM;}
<bodyObjStream>.*\r?\n           {yymore();}

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

void reset_initial_state() {
  yyrestart(yyin);
  BEGIN(INITIAL);
}
