NAME			=pdfContentExtractor
CC              	=g++
CFLAGS          	=-Wall -Wextra -ansi -pedantic -Wno-sign-compare -Werror -std=c++11 -O3
LDFLAGS			=-lfl
LEX			=flex
LFLAGS			=-D_POSIX_C_SOURCE=200809L
BISON			=bison
RM			=rm -f

all:			$(NAME)

$(NAME):		flex.o bison.o
			$(CC) $^ -o $@ $(LDFLAGS)

flex.c:			flex.l bison.h
			$(LEX) -o $@ $(LFLAGS) $<

flex.h:			flex.l
			$(LEX) -o flex.c --header-file=$@ $(LFLAGS) $<

bison.c bison.h:	bison.y flex.h
			$(BISON) $< -o bison.c -d

%.o:			%.c
			$(CC) $(CFLAGS)  $< -c

clean:
			$(RM) flex.o flex.c flex.h bison.o bison.c bison.h

fclean:			clean
			$(RM) $(NAME)

re:			fclean all
