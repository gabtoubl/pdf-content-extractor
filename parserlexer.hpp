#ifndef PARSERLEXER_HPP_
# define PARSERLEXER_HPP_

#include <cstring>
#include <vector>
#include <type_traits>

using namespace std;

typedef enum {TBOOL, TNB, TFLOAT, TNAME, TSTRING, TARR, TDIC, TNIL, TIND} eType;

class Obj {
public:
  Obj() {_content.clear();_stream = "";}
  ~Obj() {}
  template<typename T>
  void add(T content, eType type) {
    void *newContent;
    if (!(newContent = malloc(sizeof(T))))
      return;
    memcpy(newContent, &content, sizeof(T));
    _content.push_back(make_pair(type, newContent));
  }
  void addStream(string stream) {_stream = stream;}
  eType type() const {return _content.size() ?_content.back().first : TNIL;}
  void *content() const {return _content.size() ? _content.back().second : NULL;}
  string stream() const {return _stream;}
  const vector<pair<eType, void*> > &contents() const {return _content;}
protected:
  vector<pair<eType, void*> > _content;
  string _stream;
};

class Arr : public Obj {};

class Dic : public Obj {
public:
  Dic() :Obj() {_rules.clear();_stream = "";}
  void addRule(string rule) {_rules.push_back(rule);}
  vector<string> rules() const {return _rules;}
private:
  vector<string> _rules;
};

void yyerror(const char *);
void set_text_stream_state();
void reset_initial_state();

#endif /* !PARSERLEXER_HPP_ */
