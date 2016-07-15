#ifndef PARSERLEXER_HPP_
# define PARSERLEXER_HPP_

#include <string>
#include <vector>
#include <cstring>

using namespace std;

typedef enum {TBOOL, TNB, TFLOAT, TNAME, TSTRING, TARR, TDIC, TNIL, TIND} eType;

class Obj {
public:
  Obj();
  ~Obj();
  template<typename T>
  void add(T content, eType type) {
    void *newContent;
    if (!(newContent = malloc(sizeof(T))))
      return;
    memcpy(newContent, &content, sizeof(T));
    _content.push_back(make_pair(type, newContent));
  }
  void addStream(string stream);
  eType type() const;
  void *content() const;
  string stream() const;
  const vector<pair<eType, void*> > &contents() const;
protected:
  vector<pair<eType, void*> > _content;
  string _stream;
};

class Arr : public Obj {};

class Dic : public Obj {
public:
  Dic() :Obj() {_rules.clear();}
  void addRule(string rule) {_rules.push_back(rule);}
  vector<string> rules() const {return _rules;}
private:
  vector<string> _rules;
};

void yyerror(const char *);
void set_text_stream_state();
void reset_initial_state();

#endif /* !PARSERLEXER_HPP_ */
