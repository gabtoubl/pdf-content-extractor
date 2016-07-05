%{
  #include <iostream>
  #include <vector>
  #include <string>
  #include "parserlexer.hpp"
  #include "flex.h"

  using namespace std;
  vector<Obj> objList;
%}
%union  {
  char c;
  char *s;
  int i;
  bool b;
  float f;
};
%token <s> VERSION
%token COMMENT
%token OBJ
%token ENDOBJ
%token <b> BOOL
%token <i> NB
%token <f> FLOAT
%token <s> NAME
%token <s> STRING
%token ARR
%token ENDARR
%token DIC
%token ENDDIC
%token STREAM
%token <s> ENDSTREAM
%token IND
%token ENDIND
%token NIL
%token XREF
%token XREFSECTION
%token TRAILER
%token STARTXREF
%token ENDOFFILE

%%
File:		Header
		Body
		XrefTable
		Trailer;
Header:		VERSION {cout << "VERSION '"<< $1 << "'" << endl;}
		COMMENT {cout << "COMMENT" << endl;}
Body:		Objects;
Objects:	| Objects Object;
Object:		NB NB OBJ {objList.push_back(Obj($1, $2));}
		Content
		ENDOBJ;
Contents:	| Contents Content;
Content:	BOOL {cout << "BOOL: " << $1 << endl;}
		| NB {cout << "NB: " << $1 << endl;}
		| FLOAT {cout << "FLOAT: " << $1 << endl;}
		| NAME {cout << "NAME: " << $1 << endl;}
		| STRING {cout << "STRING: " << $1 << endl;}
		| Array // pareil ici
		| Dictionary Stream // et la egalement
		| NIL {cout << "NIL" << endl;}
		| IND NB NB ENDIND {cout << "IND: " << $2 << " " << $3 << " R" << endl;}
Array:		ARR {cout << "ARR" << endl;}
		Contents
		ENDARR {cout << "ENDARR" << endl;};
Dictionary:	DIC {cout << "DIC" << endl;}
		DicRules
		ENDDIC {cout << "ENDDIC" << endl;};
DicRules:	| DicRules DicRule;
DicRule:	NAME Content {cout << "RULE: " << $1 << endl;};
Stream:		| STREAM {cout << "STREAM" << endl;}
		ENDSTREAM {cout << "ENDSTREAM" << endl;}; // binary data here, copy yyleng data from $3 to have actual whole data
XrefTable:	XREF {cout << "XREF" << endl;}
		XrefSections;
XrefSections:	| XrefSections XrefSection;
XrefSection:	XREFSECTION NB NB {cout << "SECTION: " << $2 << " " << $3 << endl;}
		XrefFields;
XrefFields:	| XrefFields XrefField;
XrefField:	NB NB BOOL {cout << "FIELD: " << $1 << " " << $2 << " " << $3 << endl;};
Trailer:	TRAILER {cout << "TRAILER " << endl;}
		Dictionary
		STARTXREF {cout << "STARTXREF" << endl;}
		NB {cout << "NB: " << $6 << endl;}
		ENDOFFILE {cout << "ENDOFFILE" << endl;};
%%

void yyerror(const char *s) {
  fprintf(stderr, "Error with parsing: %s\n", s);
}

ostream& operator<<(ostream &os, const Obj &obj) {
  os << "obj:" << obj.id() << " " << obj.genId();
  return os;
}

static int printHelp() {
  cout << "usage: ./pdfContentExtractor FILE" << endl;
  return 1;
}

static int printError() {
  cout << "error: " << strerror(errno) << endl;
  return 1;
}

// pdftk fichier.pdf output fichierout.pdf
int main(int ac, char **av) {
  yyin = NULL;
  yyout = stdout;
  if (ac != 2)
    return printHelp();
  if (!(yyin = fopen(av[1], "r")))
    return printError();
  yyparse();
  for (auto &o : objList)
    cerr << o << endl;
  return 0;
}
