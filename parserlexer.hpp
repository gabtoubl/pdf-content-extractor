#ifndef PARSERLEXER_HPP_
# define PARSERLEXER_HPP_

using namespace std;

void yyerror(const char *);

class Obj {
public:
  Obj(int id, int genId) :_id(id), _genId(genId) {}
  ~Obj() {}
  int id() const {return _id;}
  int genId() const {return _genId;}
private:
  int _id, _genId;
};
ostream& operator<<(ostream&, const Obj&);


#endif /* !PARSERLEXER_HPP_ */
