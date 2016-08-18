%{
  #include <iostream>
  #include <stack>
  #include <map>
  #include "zlib.h"
  #include "parserlexer.hpp"
  #include "flex.hpp"

  using namespace std;
  map<pair<int, int>, Obj> objHash;
  Obj trailerObj;
  stack<Obj*> objStack;
  char *currentFile = NULL;
  string extractedText = "", fontName = "";
  FILE *compressedFile, *contentsFile, *outFile;
  float lastX = -1, lastY = -1, maxY = -1, lineX = -1, lineY = -1;
  bool isParagraph = false;

  float abs(float);
  void addLine();
  void closeParagraph();
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
%token OP_FONT
%token OP_NEWLINE
%token OP_PRINTARR
%token OP_PRINT
%token OP_MATRIX
%token BEGINTXT
%token ENDTXT

%start File
%%
File:		PdfFile | StreamFile;
PdfFile:       	Header
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
		| NAME {objStack.top()->add<string>(string($1, yyleng+1), TNAME);}
		| STRING {objStack.top()->add<string>(string($1, yyleng+1), TSTRING);}
		| Array
		| Dictionary Stream
		| NIL {objStack.top()->add<void*>(NULL, TNIL);}
		| IND NB NB ENDIND {objStack.top()->add<pair<int,int> >(make_pair($2,$3),TIND);}
Array:		ARR {objStack.top()->add<Arr*>(new Arr(), TARR);
		  objStack.push(*(Arr**)objStack.top()->content());}
		Contents
		ENDARR {objStack.pop();};
Dictionary:	DIC {objStack.top()->add<Dic*>(new Dic(), TDIC);
		  objStack.push(*(Dic**)objStack.top()->content());}
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

StreamFile:	TxtBlocks;
TxtBlocks:	| TxtBlocks TxtBlock;
TxtBlock:	BEGINTXT
		Commands
		ENDTXT
Commands:	| Commands Command;
Command:	NAME FLOAT OP_FONT {fontName = $1;}
		| FLOAT FLOAT OP_NEWLINE {addLine();}
		| STRING {extractedText += string($1+1, yyleng-2);} OP_PRINT
		| FLOAT FLOAT FLOAT FLOAT FLOAT FLOAT OP_MATRIX {
                  if (lastY >= 0) {
		    if (abs(lastY - $6 > 10))
                      addLine();
		    if (abs(lastY - $6 > 30))
                      closeParagraph();
		    if (abs(lastX - $5 > 10))
                      extractedText += " ";
                  }
                  maxY = lastY < 0 ? $6 : maxY;
                  lineX = lineX < 0 ? $5 : lineX;
                  lineY = lineY < 0 ? $6 : lineY;
		  lastX=$5; lastY=$6;}
		| ARR TxtArrContents ENDARR OP_PRINTARR
TxtArrContents:	| TxtArrContents TxtArrContent;
TxtArrContent:  STRING {extractedText += string($1+1, yyleng-2);}
		| FLOAT {if ($1 < -70)extractedText += " ";}

%%

float abs(float val) {
  return val > 0 ? val : -val;
}

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
  cerr << "usage: ./pdfContentExtractor FILE1 [FILE2 FILE3 ...]" << endl;
  return 1;
}

static int printError(int returnCode = 1) {
  cerr << "error: " << strerror(errno) << endl;
  return returnCode;
}

void f() {}

static void followTrailer(Obj &obj, int rulePos) {
  string rules[] = {"/Root", "/Pages", "/Contents", "/Length"};
  Dic *objDic = *(Dic**)obj.content();
  int i = 0;

  for (auto const &rule : objDic->rules()) {
    if (rule == rules[rulePos] || rule == "/Kids") {
      if (rule == "/Kids")
	--rulePos;
      eType type = objDic->contents()[i].first;
      int j = 0;
      for (auto const &r : objDic->rules()) {
	if (r == "/Type")
	  {
	    f();
	    string *typeValue = (string*)(objDic->contents()[j].second);
	    cout << "lol:"<<r<<":"<<j << endl;
	    if (*typeValue == "/Page")
	      cout << "one page here" << endl;
	    else {
	      if (objDic->contents()[j].first == TNAME)
	      cout << *typeValue <<endl;
	    }
	  }
	++j;
      }
      if (type == TIND) {
	pair<int, int> *xy = (pair<int,int>*)(objDic->contents()[i].second);
	followTrailer(objHash[*xy], rulePos + 1);
      }
      else if (type == TARR) {
	Arr *arr = *(Arr**)(objDic->contents()[i].second);
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

void initHTML(FILE *outFile) {
  string outContent = "<!DOCTYPE HTML><html><head><title>";

  outContent += currentFile;
  outContent += " - Extracted Content</title></head><body>";
  fwrite(outContent.c_str(), 1, outContent.length(), outFile);
}

void addLine() {
  string divText = "";
  static int ParentX, ParentY;

  if (!isParagraph) {
    isParagraph = true;
    divText += "<div class='paragraph' ";
    divText += "style='width: 100%;";
    divText += "position:absolute; left: ";
    divText += to_string((int)lineX);
    divText += "px; top: ";
    divText += to_string(10 + (int)(maxY - lineY));
    divText += "px;'>";
    ParentX = (int)lineX;
    ParentY = (int)(maxY - lineY);
  }
  divText += "<div class='line' ";
  divText += "style='position:absolute; left: ";
  divText += to_string((int)lineX - ParentX);
  divText += "px; top: ";
  divText += to_string((int)(maxY - lineY) - ParentY);
  divText += "px;'>";
  divText += extractedText;
  divText += "</div>";
  fwrite(divText.c_str(), 1, divText.length(), outFile);
  extractedText = "";
  lineX = -1;
  lineY = -1;
}

void closeParagraph() {
  string divText = "";

  isParagraph = false;
  fwrite("</div>", 1, 6, outFile);
}

static int parsePDF(int fileNb, char **files) {
  string cmd, outFileName;

  for (int i = 1; i < fileNb; ++i) {
    outFileName = currentFile = files[i];
    outFileName += ".html";
    extractedText = "";
    cout << currentFile << "...";
    cmd = "pdftk \"";
    cmd += files[i];
    cmd += "\" output /tmp/fixed.pdf";
    if (system(cmd.c_str()))
      return i;
    if(!(yyin = fopen("/tmp/fixed.pdf", "rb")))
      return printError(i);
    yyparse();
    if (!currentFile)
      return i;
    if(!(contentsFile = fopen("/tmp/kawaidesune", "wb+"))) // tmpfile() after debug
      return printError(i);
    cout << " OK";
    followTrailer(trailerObj, 0);
    rewind(contentsFile);
    set_text_stream_state();
    //    if (!(outFile = fopen(outFileName, "wb+")))
    if (!(outFile = fopen("swag.html", "wb+")))
      return printError(i);
    initHTML(outFile);
    yyin = contentsFile;
    yyparse();
    reset_initial_state();
    fwrite("</body></html>", 1, 14, outFile);
    fclose(outFile);
    if (!currentFile)
      return i;
    cout << " OK" << endl;
  }
  fclose(contentsFile);
  return fileNb;
}

int main(int ac, char **av) {
  int okFiles;

  if (ac < 2)
    return printHelp();
  cout << "Files that were parsed correctly:" << endl;
  okFiles = parsePDF(ac, av);
  if (okFiles != ac)
    cout << " ERROR!" << endl;
  cout << "Ratio: "<< okFiles - 1 << "/" << ac - 1 << " (" << (okFiles - 1)*100 / (ac - 1) << "%)" << endl;
  yylex_destroy();
  return 0;
}
