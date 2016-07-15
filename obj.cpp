
#include "parserlexer.hpp"

Obj::Obj() {
  _content.clear();_stream = "";
}

Obj::~Obj() {
  for (auto &obj : _content) {
    if (obj.first == TDIC)
      delete *((Dic**)obj.second);
    else if (obj.first == TARR)
      delete *((Arr**)obj.second);
    free(obj.second);
  }
}

void Obj::addStream(string stream) {
  _stream = stream;
}

eType Obj::type() const {
  return _content.size() ?_content.back().first : TNIL;
}

void *Obj::content() const {
  return _content.size() ? _content.back().second : NULL;
}

string Obj::stream() const {
  return _stream;
}

const vector<pair<eType, void*> > &Obj::contents() const {
  return _content;
}

