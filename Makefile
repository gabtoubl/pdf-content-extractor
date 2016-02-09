NAME		=search
SRCS		=main.c
OBJS		=$(SRCS:.c=.o)
CFLAGS		=-Wall -Wextra -ansi -pedantic -std=c11 -g
CC		=gcc
RM		=rm -fv

$(NAME):	$(OBJS)
		$(CC) -o $(NAME) $(OBJS)

all:		$(NAME)

clean:
		@$(RM) $(OBJS)

fclean:		clean
		@$(RM) $(NAME)

re:		fclean all

.PHONY:		all clean fclean re
