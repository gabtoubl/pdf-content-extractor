NAME			=pdfContentExtractor
SRCS			=flex.cpp	\
			 bison.cpp	\
			 obj.cpp
OBJS			=$(SRCS:.cpp=.o)
CC              	=g++
CFLAGS          	=-Wall -Wextra -ansi -pedantic -Wno-sign-compare -Werror -std=c++11 -g
LDFLAGS			=-lfl -lz
LEX			=flex
LFLAGS			=-D_POSIX_C_SOURCE=200809L
BISON			=bison
RM			=rm -f

all:			$(NAME)

$(NAME):		flex.o bison.o $(OBJS)
			$(CC) $^ -o $@ $(LDFLAGS)

flex.cpp:		flex.l bison.hpp
			$(LEX) -o $@ $(LFLAGS) $<

flex.hpp:		flex.l
			$(LEX) -o flex.cpp --header-file=$@ $(LFLAGS) $<

bison.cpp bison.hpp:	bison.y flex.hpp
			$(BISON) $< -o bison.cpp -d

%.o:			%.cpp
			$(CC) -c $< $(CFLAGS)

clean:
			$(RM) flex.[ch]pp bison.[ch]pp $(OBJS)

fclean:			clean
			$(RM) $(NAME)

re:			fclean all
