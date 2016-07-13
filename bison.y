%{
  #include <iostream>
  #include <vector>
  #include <stack>
  #include <map>
  #include <string>
  #include "zlib.h"
  #include "parserlexer.hpp"
  #include "flex.h"

  using namespace std;
  map<pair<int, int>, Obj> objHash;
  Obj trailerObj;
  stack<Obj*> objStack;
  char *currentFile = NULL;
  FILE *compressedFile, *contentsFile;
%}
%union  {
  char c;
  char *s;
  int i;
  bool b;
  float f;
};
%token <s> VERSION
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
Header:		VERSION
Body:		Objects;
Objects:	| Objects Object;
Object:		NB NB OBJ {objHash[make_pair($1, $2)] = Obj();
		  objStack.push(&objHash[make_pair($1, $2)]);}
		Content
		ENDOBJ {objStack.pop();};
Contents:	| Contents Content;
Content:	BOOL {objStack.top()->add<bool>($1, TBOOL);}
		| NB {objStack.top()->add<int>($1, TNB);}
		| FLOAT {objStack.top()->add<float>($1, TFLOAT);}
		| NAME {objStack.top()->add<char*>($1, TNAME);}
		| STRING {objStack.top()->add<char*>($1, TSTRING);}
		| Array
		| Dictionary Stream
		| NIL {objStack.top()->add<void*>(NULL, TNIL);}
		| IND NB NB ENDIND {objStack.top()->add<pair<int,int> >(make_pair($2,$3),TIND);}
Array:		ARR {objStack.top()->add<Arr>(Arr(), TARR);
		  objStack.push((Arr*)objStack.top()->content());}
		Contents
		ENDARR {objStack.pop();};
Dictionary:	DIC {objStack.top()->add<Dic>(Dic(), TDIC);
		  objStack.push((Dic*)objStack.top()->content());}
		DicRules
		ENDDIC {objStack.pop();};
DicRules:	| DicRules DicRule;
DicRule:	NAME {((Dic*)objStack.top())->addRule($1);}
		Content;
Stream:		| STREAM ENDSTREAM {objStack.top()->addStream(string($2, yyleng+1));};
XrefTable:	XREF
		XrefSections;
XrefSections:	| XrefSections XrefSection;
XrefSection:	XREFSECTION NB NB
		XrefFields;
XrefFields:	| XrefFields XrefField;
XrefField:	NB NB BOOL;
Trailer:	TRAILER {objStack.push(&trailerObj);}
		Dictionary
		STARTXREF
		NB
		ENDOFFILE {objStack.pop();};
%%



void yyerror(const char *s) {
  cerr << "Error with parsing of " << currentFile << ": " << s << endl;
  currentFile = NULL;
}

int inflate(FILE *source, FILE *dest)
{
  int ret;
  unsigned have;
  z_stream strm;
  unsigned char in[16384];
  unsigned char out[16384];

  strm.zalloc = Z_NULL; strm.zfree = Z_NULL;
  strm.opaque = Z_NULL; strm.avail_in = 0;
  strm.next_in = Z_NULL;
  ret = inflateInit(&strm);
  if (ret != Z_OK)
    return ret;
  do {
    strm.avail_in = fread(in, 1, 16384, source);
    if (ferror(source)) {
      inflateEnd(&strm);
      return Z_ERRNO;
    }
    if (strm.avail_in == 0)
      break;
    strm.next_in = in;
    do {
      strm.avail_out = 16384;
      strm.next_out = out;
      ret = inflate(&strm, Z_NO_FLUSH);
      if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_ERRNO)
	return ret;
      have = 16384 - strm.avail_out;
      if (fwrite(out, 1, have, dest) != have || ferror(dest)) {
	inflateEnd(&strm);
	return Z_ERRNO;
      }
    } while (strm.avail_out == 0);
  } while (ret != Z_STREAM_END);
  inflateEnd(&strm);
  return ret == Z_STREAM_END ? Z_OK : Z_DATA_ERROR;
}

static int printHelp() {
  cout << "usage: ./pdfContentExtractor FILE1 [FILE2 FILE3 ...]" << endl;
  return 1;
}

static int printError(int returnCode = 1) {
  cout << "error: " << strerror(errno) << endl;
  return returnCode;
}

static void followTrailer(Obj &obj, int rulePos) {
  string rules[] = {"/Root", "/Pages", "/Contents", "/Length"};
  Dic *objDic = (Dic*)obj.content();
  int i = 0;

  for (auto const &rule : objDic->rules()) {
    if (rule == rules[rulePos] || rule == "/Kids") {
      if (rule == "/Kids")
	--rulePos;
      eType type = objDic->contents()[i].first;
      if (type == TIND) {
	pair<int, int> *xy = (pair<int,int>*)(objDic->contents()[i].second);
	followTrailer(objHash[*xy], rulePos + 1);
      }
      else if (type == TARR) {
	Arr *arr = (Arr*)(objDic->contents()[i].second);
	for (auto const &item : arr->contents()) {
	  pair<int, int> *xy = (pair<int,int>*)item.second;
	  followTrailer(objHash[*xy], rulePos + 1);
	}
      }
      else if (type == TNB) {
	if (!(compressedFile = tmpfile()))
	  return (void)printError;
	fwrite(obj.stream().c_str(), 1, obj.stream().length(), compressedFile);
	rewind(compressedFile);
	inflate(compressedFile, contentsFile);
	fclose(compressedFile);
      }
    }
    ++i;
  }
}

static int parsePDF(int fileNb, char **files) {
  string cmd;
  for (int i = 1; i < fileNb; ++i) {
    currentFile = files[i];
    cout << currentFile << "... ";
    cmd = "pdftk \"";
    cmd += files[i];
    cmd += "\" output /tmp/fixed.pdf";
    if (system(cmd.c_str()))
      return i;
    if(!(yyin = fopen("/tmp/fixed.pdf", "rb")))
      return printError(i);
    yyparse();
    fclose(yyin);
    if (!currentFile)
      return i;
    reset_initial_state();
    if(!(contentsFile = tmpfile()))
      return printError(i);
    cout << "[OK]" << endl;
    followTrailer(trailerObj, 0);
    fclose(contentsFile);
  }
  return fileNb;
}

int main(int ac, char **av) {
  int okFiles;

  yyin = NULL;
  yyout = stdout;
  if (ac < 2)
    return printHelp();
  cout << "Files that were parsed correctly:" << endl;
  okFiles = parsePDF(ac, av);
  if (okFiles != ac)
    cout << "[ERROR]" << endl;
  cout << "Ratio: "<< okFiles - 1 << "/" << ac - 1 << " (" << (okFiles - 1)*100 / (ac - 1) << "%)" << endl;
  return 0;
}
